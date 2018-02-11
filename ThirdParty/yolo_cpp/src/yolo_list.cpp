#include <stdlib.h>
#include <string.h>
#include "yolo_list.h"

yolo_list *make_yolo_list()
{
	yolo_list *l = (yolo_list*)malloc(sizeof(yolo_list));
	l->size = 0;
	l->front = 0;
	l->back = 0;
	return l;
}

/*
void transfer_node(yolo_list *s, yolo_list *d, node *n)
{
    node *prev, *next;
    prev = n->prev;
    next = n->next;
    if(prev) prev->next = next;
    if(next) next->prev = prev;
    --s->size;
    if(s->front == n) s->front = next;
    if(s->back == n) s->back = prev;
}
*/

void *yolo_list_pop(yolo_list *l){
    if(!l->back) return 0;
    node *b = l->back;
    void *val = b->val;
    l->back = b->prev;
    if(l->back) l->back->next = 0;
    free(b);
    --l->size;
    
    return val;
}

void yolo_list_insert(yolo_list *l, void *val)
{
	node *new_ = (node*)malloc(sizeof(node));
	new_->val = val;
	new_->next = 0;

	if(!l->back){
		l->front = new_;
		new_->prev = 0;
	}else{
		l->back->next = new_;
		new_->prev = l->back;
	}
	l->back = new_;
	++l->size;
}

void free_node(node *n)
{
	node *next;
	while(n) {
		next = n->next;
		free(n);
		n = next;
	}
}

void free_yolo_list(yolo_list *l)
{
	free_node(l->front);
	free(l);
}

void free_yolo_list_contents(yolo_list *l)
{
	node *n = l->front;
	while(n){
		free(n->val);
		n = n->next;
	}
}

void **yolo_list_to_array(yolo_list *l)
{
    void **a = (void**)calloc(l->size, sizeof(void*));
    int count = 0;
    node *n = l->front;
    while(n){
        a[count++] = n->val;
        n = n->next;
    }
    return a;
}
