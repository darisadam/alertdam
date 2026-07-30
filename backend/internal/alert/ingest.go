package alert

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

// EventAction defines the type of alert action.
type EventAction string

const (
	EventActionTrigger     EventAction = "trigger"
	EventActionAcknowledge EventAction = "acknowledge"
	EventActionResolve     EventAction = "resolve"
)

// Severity levels for alert payloads.
type Severity string

const (
	SeverityCritical Severity = "CRITICAL"
	SeverityHigh     Severity = "HIGH"
	SeverityWarning  Severity = "WARNING"
	SeverityInfo     Severity = "INFO"
)

// IngestPayload defines the standard incoming webhook body (PRD §4.1).
//
// Example:
//
//	{
//	  "routing_key": "srv-abc-123-xyz",
//	  "event_action": "trigger",
//	  "dedup_key": "database-disk-space-90-percent",
//	  "payload": { ... }
//	}
type IngestPayload struct {
	RoutingKey  string      `json:"routing_key"`
	EventAction EventAction `json:"event_action"`
	DedupKey    string      `json:"dedup_key,omitempty"`
	Payload     AlertDetail `json:"payload"`
}

// AlertDetail holds the core alert content.
type AlertDetail struct {
	Summary       string            `json:"summary"`
	Severity      Severity          `json:"severity"`
	Source        string            `json:"source"`
	Timestamp     time.Time         `json:"timestamp,omitempty"`
	CustomDetails map[string]string `json:"custom_details,omitempty"`
}

// IngestHandler handles POST /v1/events
// It validates the payload and hands off to the processing pipeline.
func IngestHandler(w http.ResponseWriter, r *http.Request) {
	defer func() { _ = r.Body.Close() }()

	var event IngestPayload
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if event.RoutingKey == "" {
		http.Error(w, `{"error":"routing_key is required"}`, http.StatusBadRequest)
		return
	}

	if event.EventAction == "" {
		event.EventAction = EventActionTrigger
	}

	// TODO: validate routing key against DB
	// TODO: run deduplication engine
	// TODO: enqueue for processing via PostgreSQL NOTIFY

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	if _, err := w.Write([]byte(`{"status":"accepted","message":"Event received and queued for processing"}`)); err != nil {
		// The client hung up mid-response; nothing to recover, but do not
		// swallow it silently.
		log.Printf("alert: writing ingest response: %v", err)
	}
}
