#ifndef OPTION_list_H
#define OPTION_list_H

#include "yolo_list.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char *key;
    char *val;
    int used;
} kvp;


yolo_list *read_data_cfg(char *filename);

int read_option(char *s, yolo_list *options);

void option_insert(yolo_list *l, char *key, char *val);

char *option_find(yolo_list *l, char *key);

char *option_find_str(yolo_list *l, char *key, char *def);

int option_find_int(yolo_list *l, char *key, int def);

int option_find_int_quiet(yolo_list *l, char *key, int def);

float option_find_float(yolo_list *l, char *key, float def);

float option_find_float_quiet(yolo_list *l, char *key, float def);

void option_unused(yolo_list *l);

#ifdef __cplusplus
}
#endif

#endif
