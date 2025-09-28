#include "faust.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Minimal UI management
static void printHGroup(void *ui_interface, const char *label) {
  printf("HGroup [label %s]\n", label);
}

static void printVGroup(void *ui_interface, const char *label) {
  printf("VGroup [label %s]\n", label);
}

static void printOpenTabBox(void *ui_interface, const char *label) {
  printf("OpenTabBox [label %s]\n", label);
}

static void printCloseBox(void *ui_interface) { printf("CloseBox\n"); }

static void printDeclare(void *ui_interface, FAUSTFLOAT *zone, const char *key,
                         const char *value) {
  printf("Declare [key %s value %s]\n", key, value);
}

static void printVerticalSlider(void *ui_interface, const char *label,
                                FAUSTFLOAT *zone, FAUSTFLOAT init,
                                FAUSTFLOAT min, FAUSTFLOAT max,
                                FAUSTFLOAT step) {
  printf("VerticalSlider [label %s init: %f min: %f, max: %f step: %f]\n",
         label, init, min, max, step);
}

static void printHorizontalSlider(void *ui_interface, const char *label,
                                  FAUSTFLOAT *zone, FAUSTFLOAT init,
                                  FAUSTFLOAT min, FAUSTFLOAT max,
                                  FAUSTFLOAT step) {
  printf("HorizontalSlider [label %s init: %f min: %f max: %f step: %f]\n",
         label, init, min, max, step);
}

static void printNumEntry(void *ui_interface, const char *label,
                          FAUSTFLOAT *zone, FAUSTFLOAT init, FAUSTFLOAT min,
                          FAUSTFLOAT max, FAUSTFLOAT step) {
  printf("NumEntry [label %s init: %f min: %f max: %f step: %f]\n", label, init,
         min, max, step);
}

static void printButton(void *ui_interface, const char *label,
                        FAUSTFLOAT *zone) {
  printf("Button [label %s]\n", label);
}

static void printCheckButton(void *ui_interface, const char *label,
                             FAUSTFLOAT *zone) {
  printf("CheckButton [label %s]\n", label);
}

static void printHorizontalBargraph(void *ui_interface, const char *label,
                                    FAUSTFLOAT *zone, FAUSTFLOAT min,
                                    FAUSTFLOAT max) {
  printf("HorizontalBargraph [label %s, min: %f, max: %f]\n", label, min, max);
}

static void printVerticalBargraph(void *ui_interface, const char *label,
                                  FAUSTFLOAT *zone, FAUSTFLOAT min,
                                  FAUSTFLOAT max) {
  printf("VerticalBargraph [label %s, min: %f, max: %f]\n", label, min, max);
}

// Minimal management using zone

// Keep a control and lik to the next one
typedef struct ControlZone {
  const char *fLabel;
  FAUSTFLOAT *fZone;
  FAUSTFLOAT fInit;
  FAUSTFLOAT fMin;
  FAUSTFLOAT fMax;
  FAUSTFLOAT fStep;
  struct ControlZone *fNext;
} ControlZone;

static ControlZone *newControl(const char *label, FAUSTFLOAT *zone,
                               FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max,
                               FAUSTFLOAT step) {
  ControlZone *ctrl = (ControlZone *)calloc(1, sizeof(ControlZone));
  ctrl->fLabel = label;
  ctrl->fZone = zone;
  ctrl->fInit = init;
  ctrl->fMin = min;
  ctrl->fMax = max;
  ctrl->fStep = step;
  ctrl->fNext = NULL;
  return ctrl;
}

static void initControl(ControlZone *ctrl) {
  ctrl->fLabel = NULL;
  ctrl->fZone = NULL;
  ctrl->fInit = 0;
  ctrl->fMin = 0;
  ctrl->fMax = 0;
  ctrl->fStep = 0;
  ctrl->fNext = NULL;
}

static void printControl(ControlZone *ctrl) {
  if (ctrl != NULL) {
    if (ctrl->fLabel != NULL) {
      printf("Label %s ", ctrl->fLabel);
    }
    if (ctrl->fZone != NULL) {
      printf("Zone %p ", ctrl->fZone);
    }
    printf("Init %f ", ctrl->fInit);
    printf("Min %f ", ctrl->fMin);
    printf("Max %f ", ctrl->fMax);
    printf("Step %f \n", ctrl->fStep);
  }
}

static void printControls(ControlZone *ctrl) {
  while (ctrl != NULL) {
    printControl(ctrl);
    ctrl = ctrl->fNext;
  }
}

static void freeControls(ControlZone *ctrl) {
  while (ctrl != NULL) {
    ControlZone *tmp = ctrl;
    ctrl = ctrl->fNext;
    free(tmp);
  }
}

static void setParamValue(ControlZone *ctrl, const char *label,
                          FAUSTFLOAT value) {
  while (ctrl != NULL) {
    if (ctrl->fLabel && strcmp(ctrl->fLabel, label) == 0) {
      *ctrl->fZone = value;
      return;
    }
    ctrl = ctrl->fNext;
  }
}

static FAUSTFLOAT getParamValue(ControlZone *ctrl, const char *label) {
  while (ctrl != NULL) {
    if (ctrl->fLabel && strcmp(ctrl->fLabel, label) == 0) {
      return *ctrl->fZone;
    }
    ctrl = ctrl->fNext;
  }
  return 0;
}

static void ignoreHGroup(void *ui_interface, const char *label) {}

static void ignoreVGroup(void *ui_interface, const char *label) {}

static void ignoreOpenTabBox(void *ui_interface, const char *label) {}

static void ignoreCloseBox(void *ui_interface) {}

static void ignoreDeclare(void *ui_interface, FAUSTFLOAT *zone, const char *key,
                          const char *value) {}

static void addVerticalSlider(void *ui_interface, const char *label,
                              FAUSTFLOAT *zone, FAUSTFLOAT init, FAUSTFLOAT min,
                              FAUSTFLOAT max, FAUSTFLOAT step) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, init, min, max, step);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}

static void addHorizontalSlider(void *ui_interface, const char *label,
                                FAUSTFLOAT *zone, FAUSTFLOAT init,
                                FAUSTFLOAT min, FAUSTFLOAT max,
                                FAUSTFLOAT step) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, init, min, max, step);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}

static void addNumEntry(void *ui_interface, const char *label, FAUSTFLOAT *zone,
                        FAUSTFLOAT init, FAUSTFLOAT min, FAUSTFLOAT max,
                        FAUSTFLOAT step) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, init, min, max, step);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}

static void addButton(void *ui_interface, const char *label, FAUSTFLOAT *zone) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, 0, 0, 1, 1);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}

static void addCheckButton(void *ui_interface, const char *label,
                           FAUSTFLOAT *zone) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, 0, 0, 1, 1);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}

static void addHorizontalBargraph(void *ui_interface, const char *label,
                                  FAUSTFLOAT *zone, FAUSTFLOAT min,
                                  FAUSTFLOAT max) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, 0, min, max, 0);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}

static void addVerticalBargraph(void *ui_interface, const char *label,
                                FAUSTFLOAT *zone, FAUSTFLOAT min,
                                FAUSTFLOAT max) {
  ControlZone *ctrl_list = (ControlZone *)ui_interface;
  ControlZone *ctrl = newControl(label, zone, 0, min, max, 0);
  ctrl->fNext = ctrl_list->fNext;
  ctrl_list->fNext = ctrl;
}
