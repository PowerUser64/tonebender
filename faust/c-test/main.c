#define BUFFER_SIZE 20
#define SAMPLE_RATE 4800

#include <math.h>

// including .c files, cry about it
#include "faust_prints.c"
#include "mydsp.gen.c"

int main(int argc, char *argv[]) {
  mydsp *dsp = newmydsp();

  printf("DSP inputs: %d\n", getNumInputsmydsp(dsp));
  printf("DSP outputs: %d\n", getNumOutputsmydsp(dsp));

  // Init with audio driver SR
  initmydsp(dsp, SAMPLE_RATE);

  // Add controls print methods
  UIGlue ui_glue;
  ui_glue.openHorizontalBox = printHGroup;
  ui_glue.openVerticalBox = printVGroup;
  ui_glue.openTabBox = printOpenTabBox;
  ui_glue.closeBox = printCloseBox;
  ui_glue.addButton = printButton;
  ui_glue.addCheckButton = printCheckButton;
  ui_glue.addVerticalSlider = printVerticalSlider;
  ui_glue.addHorizontalSlider = printHorizontalSlider;
  ui_glue.addNumEntry = printNumEntry;
  ui_glue.addHorizontalBargraph = printHorizontalBargraph;
  ui_glue.addVerticalBargraph = printVerticalBargraph;
  ui_glue.declare = printDeclare;

  // Print all controls
  buildUserInterfacemydsp(dsp, &ui_glue);

  // Add controls handling methods
  UIGlue ctrl_glue;
  ControlZone *ctrl_list = newControl(NULL, NULL, 0, 0, 0, 0);
  initControl(ctrl_list);

  ctrl_glue.uiInterface = ctrl_list;
  ctrl_glue.openHorizontalBox = ignoreHGroup;
  ctrl_glue.openVerticalBox = ignoreVGroup;
  ctrl_glue.openTabBox = ignoreOpenTabBox;
  ctrl_glue.closeBox = ignoreCloseBox;
  ctrl_glue.addButton = addButton;
  ctrl_glue.addCheckButton = addCheckButton;
  ctrl_glue.addVerticalSlider = addVerticalSlider;
  ctrl_glue.addHorizontalSlider = addHorizontalSlider;
  ctrl_glue.addNumEntry = addNumEntry;
  ctrl_glue.addHorizontalBargraph = addHorizontalBargraph;
  ctrl_glue.addVerticalBargraph = addVerticalBargraph;
  ctrl_glue.declare = ignoreDeclare;

  // Get all controls
  buildUserInterfacemydsp(dsp, &ctrl_glue);

  // Print all labels
  printControls(ctrl_list);

  // Set a control using its label
  setParamValue(ctrl_list, "Foo", 0.0);
  setParamValue(ctrl_list, "Bar", 20);

  // Compute one buffer
  FAUSTFLOAT *inputs[getNumInputsmydsp(dsp)];
  FAUSTFLOAT *outputs[getNumOutputsmydsp(dsp)];
  for (int chan = 0; chan < getNumInputsmydsp(dsp); ++chan) {
    inputs[chan] = (FAUSTFLOAT *)malloc(sizeof(FAUSTFLOAT) * BUFFER_SIZE);
  }
  for (int chan = 0; chan < getNumOutputsmydsp(dsp); ++chan) {
    outputs[chan] = (FAUSTFLOAT *)malloc(sizeof(FAUSTFLOAT) * BUFFER_SIZE);
  }
  computemydsp(dsp, BUFFER_SIZE, inputs, outputs);

  // Print output buffers
  for (int frame = 0; frame < BUFFER_SIZE; ++frame) {
    for (int chan = 0; chan < getNumOutputsmydsp(dsp); ++chan) {
      printf("Audio output chan: %d sample: %f\n", chan, outputs[chan][frame]);
    }
  }

  // Deallocation
  freeControls(ctrl_list);

  for (int chan = 0; chan < getNumInputsmydsp(dsp); ++chan) {
    free(inputs[chan]);
  }
  for (int chan = 0; chan < getNumOutputsmydsp(dsp); ++chan) {
    free(outputs[chan]);
  }
  deletemydsp(dsp);
}
