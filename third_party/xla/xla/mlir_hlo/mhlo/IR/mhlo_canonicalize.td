/* Copyright 2019 The OpenXLA Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

// This is the canonicalize pattern definition file.

include "mlir/IR/OpBase.td"
include "mhlo/IR/hlo_ops.td"
include "mhlo/IR/hlo_utils.td"

def UnaryToBinaryEinsumEq : NativeCodeCall<
  "$_builder.getStringAttr(\",\" + $0.getValue().str())">;

def GetI64DenseElementsAttr : NativeCodeCall<
  "$0.mapValues($_builder.getI64Type(), [](llvm::APInt x) { return x.sext(64); })">;

// A dynamic reshape of a dynamic reshape is a dynamic reshape.
def RemoveRedundantDynamicReshape : Pat<
  (MHLO_DynamicReshapeOp (MHLO_DynamicReshapeOp $operand, $shape1), $shape2),
  (MHLO_DynamicReshapeOp $operand, $shape2)>;

// A dynamic broadcast of a dynamic reshape with the same shape operand
// is a dynamic reshape.
def RemoveRedundantDynamicBroadcast : Pat<
  (MHLO_DynamicBroadcastInDimOp
    (MHLO_DynamicReshapeOp $operand, $shape),
    $shape,
    IdentityBroadcastDims,
    $known_expanding_dimensions,
    $known_nonexpanding_dimensions),
  (MHLO_DynamicReshapeOp $operand, $shape)>;


// Convert DPad to Pad if edge_padding_low, edge_padding_high and
// interior_padding are constant.
def DPadToPad: Pat<
          (MHLO_DynamicPadOp $input,
            $padding_value,
            (ConstantLikeMatcher AnyIntElementsAttr:$edge_padding_low),
            (ConstantLikeMatcher AnyIntElementsAttr:$edge_padding_high),
            (ConstantLikeMatcher AnyIntElementsAttr:$interior_padding)),
          (MHLO_PadOp $input, $padding_value,
            (GetI64DenseElementsAttr (CastIntElementsAttr $edge_padding_low)),
            (GetI64DenseElementsAttr (CastIntElementsAttr $edge_padding_high)),
            (GetI64DenseElementsAttr (CastIntElementsAttr $interior_padding)))>;

// Convert RealDynamicSliceOp to SliceOp if start_indices, limit_indices and
// strides are constant.
def RealDSliceToSlice: Pat<
          (MHLO_RealDynamicSliceOp $operand,
            (ConstantLikeMatcher AnyIntElementsAttr:$start_indices),
            (ConstantLikeMatcher AnyIntElementsAttr:$limit_indices),
            (ConstantLikeMatcher AnyIntElementsAttr:$strides)),
          (MHLO_SliceOp $operand,
            (GetI64DenseElementsAttr (CastIntElementsAttr $start_indices)),
            (GetI64DenseElementsAttr (CastIntElementsAttr $limit_indices)),
            (GetI64DenseElementsAttr (CastIntElementsAttr $strides)))>;
