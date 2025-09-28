import("stdfaust.lib");

// Simple faust program that generates a sine wave

process = os.osc(440) * os.osc(1) * 1/10 <: _,_;
