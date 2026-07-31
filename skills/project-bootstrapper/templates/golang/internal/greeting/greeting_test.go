package greeting

import "testing"

func TestGreeting(t *testing.T) {
	want := "Hello, world!"
	if got := Greeting(); got != want {
		t.Fatalf("Greeting() = %q, want %q", got, want)
	}
}
