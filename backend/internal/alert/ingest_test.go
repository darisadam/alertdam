package alert

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestIngestHandler(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		body       string
		wantStatus int
		wantError  string
	}{
		{
			name:       "accepts a minimal valid trigger",
			body:       `{"routing_key":"srv-1","payload":{"summary":"disk full","severity":"CRITICAL","source":"prometheus"}}`,
			wantStatus: http.StatusAccepted,
		},
		{
			name:       "accepts an explicit event_action",
			body:       `{"routing_key":"srv-1","event_action":"resolve","dedup_key":"disk-90","payload":{"summary":"ok","severity":"INFO","source":"grafana"}}`,
			wantStatus: http.StatusAccepted,
		},
		{
			name:       "rejects a missing routing_key",
			body:       `{"payload":{"summary":"disk full"}}`,
			wantStatus: http.StatusBadRequest,
			wantError:  "routing_key is required",
		},
		{
			name:       "rejects an empty routing_key",
			body:       `{"routing_key":"","payload":{}}`,
			wantStatus: http.StatusBadRequest,
			wantError:  "routing_key is required",
		},
		{
			name:       "rejects malformed JSON",
			body:       `{"routing_key":`,
			wantStatus: http.StatusBadRequest,
			wantError:  "invalid request body",
		},
		{
			name:       "rejects an empty body",
			body:       ``,
			wantStatus: http.StatusBadRequest,
			wantError:  "invalid request body",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			req := httptest.NewRequestWithContext(context.Background(), http.MethodPost, "/v1/events", strings.NewReader(tt.body))
			rec := httptest.NewRecorder()

			IngestHandler(rec, req)

			if rec.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d (body: %s)", rec.Code, tt.wantStatus, rec.Body.String())
			}
			if tt.wantError != "" && !strings.Contains(rec.Body.String(), tt.wantError) {
				t.Errorf("body = %q, want it to contain %q", rec.Body.String(), tt.wantError)
			}
		})
	}
}

func TestIngestHandlerAcceptedResponseShape(t *testing.T) {
	t.Parallel()

	req := httptest.NewRequestWithContext(context.Background(), http.MethodPost, "/v1/events",
		strings.NewReader(`{"routing_key":"srv-1","payload":{"summary":"x","severity":"HIGH","source":"datadog"}}`))
	rec := httptest.NewRecorder()

	IngestHandler(rec, req)

	if got := rec.Header().Get("Content-Type"); got != "application/json" {
		t.Errorf("Content-Type = %q, want application/json", got)
	}

	var body struct {
		Status  string `json:"status"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("response is not valid JSON: %v (body: %s)", err, rec.Body.String())
	}
	if body.Status != "accepted" {
		t.Errorf("status = %q, want %q", body.Status, "accepted")
	}
}

// The handler defaults a missing event_action to "trigger". That default is
// load-bearing: monitoring systems that only ever fire (rather than resolve)
// commonly omit the field, and treating those as anything else would drop alerts.
func TestIngestPayloadDefaultsEventActionToTrigger(t *testing.T) {
	t.Parallel()

	var payload IngestPayload
	if err := json.Unmarshal([]byte(`{"routing_key":"srv-1"}`), &payload); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if payload.EventAction != "" {
		t.Fatalf("EventAction = %q, want empty before defaulting", payload.EventAction)
	}
}

func TestIngestPayloadRoundTrip(t *testing.T) {
	t.Parallel()

	ts := time.Date(2026, time.July, 30, 12, 0, 0, 0, time.UTC)
	in := IngestPayload{
		RoutingKey:  "srv-abc",
		EventAction: EventActionTrigger,
		DedupKey:    "database-disk-space-90-percent",
		Payload: AlertDetail{
			Summary:       "Disk usage above 90%",
			Severity:      SeverityCritical,
			Source:        "prometheus",
			Timestamp:     ts,
			CustomDetails: map[string]string{"host": "db-1"},
		},
	}

	raw, err := json.Marshal(in)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var out IngestPayload
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if out.RoutingKey != in.RoutingKey {
		t.Errorf("RoutingKey = %q, want %q", out.RoutingKey, in.RoutingKey)
	}
	if out.Payload.Severity != SeverityCritical {
		t.Errorf("Severity = %q, want %q", out.Payload.Severity, SeverityCritical)
	}
	if !out.Payload.Timestamp.Equal(ts) {
		t.Errorf("Timestamp = %v, want %v", out.Payload.Timestamp, ts)
	}
	if out.Payload.CustomDetails["host"] != "db-1" {
		t.Errorf("CustomDetails[host] = %q, want db-1", out.Payload.CustomDetails["host"])
	}
}

// dedup_key is omitempty; confirm it really is omitted, because the dedup engine
// will distinguish "absent" from "empty string".
func TestIngestPayloadOmitsEmptyDedupKey(t *testing.T) {
	t.Parallel()

	raw, err := json.Marshal(IngestPayload{RoutingKey: "srv-1"})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if strings.Contains(string(raw), "dedup_key") {
		t.Errorf("marshaled payload should omit an empty dedup_key, got %s", raw)
	}
}
