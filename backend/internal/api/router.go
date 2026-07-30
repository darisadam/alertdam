package api

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// NewRouter creates and configures the main HTTP router.
func NewRouter() http.Handler {
	r := chi.NewRouter()

	// --- Middleware ---
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Heartbeat("/health"))

	// --- API Routes ---
	r.Route("/v1", func(r chi.Router) {
		// Alert Ingestion
		r.Post("/events", handleIngestEvent)

		// Incidents
		r.Get("/incidents", handleListIncidents)
		r.Get("/incidents/{id}", handleGetIncident)
		r.Post("/incidents/{id}/acknowledge", handleAcknowledgeIncident)
		r.Post("/incidents/{id}/resolve", handleResolveIncident)
		r.Post("/incidents/{id}/escalate", handleEscalateIncident)

		// On-Call Schedules
		r.Get("/schedules", handleListSchedules)
		r.Post("/schedules", handleCreateSchedule)
		r.Get("/schedules/{id}", handleGetSchedule)
		r.Put("/schedules/{id}", handleUpdateSchedule)
		r.Delete("/schedules/{id}", handleDeleteSchedule)
		r.Get("/schedules/{id}/feed.ics", handleScheduleIcal) // RFC 5545

		// Escalation Policies
		r.Get("/policies", handleListPolicies)
		r.Post("/policies", handleCreatePolicy)
		r.Put("/policies/{id}", handleUpdatePolicy)
		r.Delete("/policies/{id}", handleDeletePolicy)

		// Integration Webhooks (inbound from monitoring tools)
		r.Post("/webhooks/alertmanager", handleAlertmanagerWebhook)
		r.Post("/webhooks/grafana", handleGrafanaWebhook)
		r.Post("/webhooks/datadog", handleDatadogWebhook)
		r.Post("/webhooks/generic", handleGenericWebhook)

		// Chat Integration Callbacks
		r.Post("/webhooks/slack/actions", handleSlackAction)
		r.Post("/webhooks/slack/events", handleSlackEvent)
		r.Post("/webhooks/discord", handleDiscordWebhook)
		r.Post("/webhooks/telegram", handleTelegramWebhook)
	})

	return r
}

// --- Stub Handlers ---
// These will be implemented in their respective packages.

func handleIngestEvent(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusAccepted, map[string]string{"status": "accepted"})
}

func handleListIncidents(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusOK, []any{})
}

func handleGetIncident(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}

func handleAcknowledgeIncident(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}

func handleResolveIncident(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}

func handleEscalateIncident(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}

func handleListSchedules(w http.ResponseWriter, r *http.Request) { respond(w, http.StatusOK, []any{}) }
func handleCreateSchedule(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleGetSchedule(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleUpdateSchedule(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleDeleteSchedule(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleScheduleIcal(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleListPolicies(w http.ResponseWriter, r *http.Request) { respond(w, http.StatusOK, []any{}) }
func handleCreatePolicy(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleUpdatePolicy(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleDeletePolicy(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusNotImplemented, map[string]string{"error": "not implemented"})
}
func handleAlertmanagerWebhook(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusAccepted, map[string]string{"status": "accepted"})
}
func handleGrafanaWebhook(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusAccepted, map[string]string{"status": "accepted"})
}
func handleDatadogWebhook(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusAccepted, map[string]string{"status": "accepted"})
}
func handleGenericWebhook(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusAccepted, map[string]string{"status": "accepted"})
}
func handleSlackAction(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusOK, map[string]string{"status": "ok"})
}
func handleSlackEvent(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusOK, map[string]string{"status": "ok"})
}
func handleDiscordWebhook(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusOK, map[string]string{"status": "ok"})
}
func handleTelegramWebhook(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusOK, map[string]string{"status": "ok"})
}

// respond writes a JSON response.
func respond(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
