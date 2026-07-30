package main

import "testing"

func TestResolvePort(t *testing.T) {
	tests := []struct {
		name    string
		env     string
		setEnv  bool
		want    int
		wantErr bool
	}{
		{name: "defaults when unset", setEnv: false, want: defaultPort},
		{name: "defaults when empty", env: "", setEnv: true, want: defaultPort},
		{name: "accepts a valid port", env: "9090", setEnv: true, want: 9090},
		{name: "accepts the lowest port", env: "1", setEnv: true, want: 1},
		{name: "accepts the highest port", env: "65535", setEnv: true, want: 65535},
		{name: "rejects non-numeric", env: "eighty-eighty", setEnv: true, wantErr: true},
		{name: "rejects zero", env: "0", setEnv: true, wantErr: true},
		{name: "rejects negative", env: "-1", setEnv: true, wantErr: true},
		{name: "rejects out of range", env: "65536", setEnv: true, wantErr: true},
		{name: "rejects injection attempt", env: "8080\nFAKE LOG LINE", setEnv: true, wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setEnv {
				t.Setenv("APP_PORT", tt.env)
			}

			got, err := resolvePort()
			if tt.wantErr {
				if err == nil {
					t.Fatalf("resolvePort() = %d, want an error", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("resolvePort() error = %v, want nil", err)
			}
			if got != tt.want {
				t.Errorf("resolvePort() = %d, want %d", got, tt.want)
			}
		})
	}
}
