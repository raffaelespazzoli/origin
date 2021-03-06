package testing

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type UnknownObject struct {
	metav1.TypeMeta
}

func (obj *UnknownObject) GetObjectKind() schema.ObjectKind { return &obj.TypeMeta }
