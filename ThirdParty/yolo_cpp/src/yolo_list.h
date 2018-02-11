#ifndef yolo_list_H
#define yolo_list_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct node {
    void *val;
    struct node *next;
    struct node *prev;
} node;

typedef struct yolo_list {
    int size;
    node *front;
    node *back;
} yolo_list;

yolo_list *make_yolo_list();
int yolo_list_find(yolo_list *l, void *val);

void yolo_list_insert(yolo_list *, void *);

void **yolo_list_to_array(yolo_list *l);

void free_yolo_list(yolo_list *l);
void free_yolo_list_contents(yolo_list *l);

#ifdef __cplusplus
}
#endif

#endif
