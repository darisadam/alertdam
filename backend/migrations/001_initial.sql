-- =============================================================================
-- PagerDam — Initial Database Schema
-- Migration: 001_initial.sql
-- =============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- Users & Authentication
-- =============================================================================
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    avatar_url  TEXT,
    timezone    TEXT NOT NULL DEFAULT 'UTC',
    role        TEXT NOT NULL DEFAULT 'member', -- member | admin
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- Integrations (Inbound Webhook Routes)
-- =============================================================================
CREATE TABLE integrations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    routing_key     TEXT NOT NULL UNIQUE,   -- the secret key in POST /v1/events
    type            TEXT NOT NULL,          -- prometheus | grafana | datadog | generic
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- On-Call Schedules
-- =============================================================================
CREATE TABLE schedules (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    timezone    TEXT NOT NULL DEFAULT 'UTC',
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE schedule_layers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    rotation_type   TEXT NOT NULL DEFAULT 'weekly', -- daily | weekly | custom
    start_at        TIMESTAMPTZ NOT NULL,
    handoff_time    TIME NOT NULL DEFAULT '09:00:00',
    layer_order     INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE schedule_layer_users (
    layer_id    UUID NOT NULL REFERENCES schedule_layers(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    position    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (layer_id, user_id)
);

CREATE TABLE schedule_overrides (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_at    TIMESTAMPTZ NOT NULL,
    end_at      TIMESTAMPTZ NOT NULL,
    created_by  UUID REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- Escalation Policies
-- =============================================================================
CREATE TABLE escalation_policies (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    description TEXT,
    repeat_count INT NOT NULL DEFAULT 0,  -- 0 = no repeat
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE escalation_steps (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id       UUID NOT NULL REFERENCES escalation_policies(id) ON DELETE CASCADE,
    step_number     INT NOT NULL,
    escalation_delay_minutes INT NOT NULL DEFAULT 5,  -- wait before escalating to next step
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE escalation_step_targets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    step_id     UUID NOT NULL REFERENCES escalation_steps(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL,  -- user | schedule | channel
    target_id   UUID,           -- user_id or schedule_id
    channel     TEXT,           -- slack_channel | discord_channel | telegram_chat_id
    notify_via  TEXT NOT NULL   -- slack | discord | telegram | push | voice | email
);

-- =============================================================================
-- Incidents
-- =============================================================================
CREATE TABLE incidents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           TEXT NOT NULL,
    description     TEXT,
    severity        TEXT NOT NULL DEFAULT 'WARNING', -- CRITICAL | HIGH | WARNING | INFO
    status          TEXT NOT NULL DEFAULT 'firing',  -- firing | acknowledged | resolved
    dedup_key       TEXT,                            -- for deduplication
    routing_key     TEXT REFERENCES integrations(routing_key),
    source          TEXT,
    integration_id  UUID REFERENCES integrations(id),
    policy_id       UUID REFERENCES escalation_policies(id),
    assignee_id     UUID REFERENCES users(id),
    acknowledged_at TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique active incident per dedup_key (prevents duplicate incidents)
CREATE UNIQUE INDEX incidents_active_dedup_key_idx
    ON incidents (dedup_key)
    WHERE status != 'resolved' AND dedup_key IS NOT NULL;

CREATE TABLE incident_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    user_id     UUID REFERENCES users(id),
    event_type  TEXT NOT NULL,  -- triggered | acknowledged | resolved | escalated | commented | note
    message     TEXT,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- Notification Queue (PostgreSQL-native, no Redis required)
-- =============================================================================
CREATE TABLE notification_queue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id     UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    target_type     TEXT NOT NULL,  -- user | channel
    target_id       TEXT NOT NULL,
    notify_via      TEXT NOT NULL,  -- slack | discord | telegram | push | voice | email
    payload         JSONB NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending',  -- pending | processing | sent | failed
    attempts        INT NOT NULL DEFAULT 0,
    last_attempted  TIMESTAMPTZ,
    scheduled_for   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for queue processing (FOR UPDATE SKIP LOCKED pattern)
CREATE INDEX notification_queue_pending_idx
    ON notification_queue (scheduled_for ASC)
    WHERE status = 'pending';

-- =============================================================================
-- Chat Integration Mappings
-- =============================================================================
CREATE TABLE chat_integrations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform    TEXT NOT NULL,  -- slack | discord | telegram | teams | whatsapp
    name        TEXT NOT NULL,
    config      JSONB NOT NULL, -- platform-specific config (channel IDs, tokens, etc.)
    enabled     BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- Indexes
-- =============================================================================
CREATE INDEX incidents_status_idx ON incidents (status);
CREATE INDEX incidents_severity_idx ON incidents (severity);
CREATE INDEX incidents_created_at_idx ON incidents (created_at DESC);
CREATE INDEX incident_events_incident_id_idx ON incident_events (incident_id);
CREATE INDEX schedule_overrides_schedule_id_idx ON schedule_overrides (schedule_id);
