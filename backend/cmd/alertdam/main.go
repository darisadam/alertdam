package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/darisadam/alertdam/internal/api"
)

// Build metadata, injected at link time via -ldflags -X. Declaring these is
// what makes the Dockerfile's and GoReleaser's -X flags take effect; the Go
// linker silently ignores -X for a symbol that does not exist.
var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

const (
	defaultPort     = 8080
	shutdownTimeout = 30 * time.Second
)

// resolvePort reads APP_PORT and validates it. Validating rather than
// interpolating the raw environment value keeps untrusted input out of both the
// listen address and the log line.
func resolvePort() (int, error) {
	raw := os.Getenv("APP_PORT")
	if raw == "" {
		return defaultPort, nil
	}
	port, err := strconv.Atoi(raw)
	if err != nil {
		return 0, fmt.Errorf("APP_PORT must be a number, got %q: %w", raw, err)
	}
	if port < 1 || port > 65535 {
		return 0, fmt.Errorf("APP_PORT must be between 1 and 65535, got %d", port)
	}
	return port, nil
}

func main() {
	if err := run(); err != nil {
		log.Printf("fatal: %v", err)
		os.Exit(1)
	}
}

// run holds the real body of main so that deferred cleanup actually runs; an
// os.Exit or log.Fatal inside main would skip every pending defer.
func run() error {
	port, err := resolvePort()
	if err != nil {
		return err
	}

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		Handler:      api.NewRouter(),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		log.Printf("🚨 AlertDam %s (commit %s, built %s) starting on port %d", version, commit, date, port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- fmt.Errorf("failed to start server: %w", err)
			return
		}
		serveErr <- nil
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-serveErr:
		// The listener failed before any signal arrived.
		return err
	case sig := <-quit:
		log.Printf("received %s, shutting down AlertDam...", sig)
	}

	ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		return fmt.Errorf("server forced to shutdown: %w", err)
	}

	log.Println("AlertDam stopped.")
	return nil
}
