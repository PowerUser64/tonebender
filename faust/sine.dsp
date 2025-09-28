import("stdfaust.lib");

// Test faust program that generates a sine wave

process = os.osc(440) * os.osc(1);
