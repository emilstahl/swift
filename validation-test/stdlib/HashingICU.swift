// RUN: %target-run-simple-swift | FileCheck %s

// REQUIRES: OS=linux-gnu

// Validation of hashes produced by ICU-based methods used on linux. Doesn't
// use StdlibUnittest because that doesn't work on linux yet. May go away in
// favour of the more comprehensive tests that already exist once it does.

// ASCII strings
// CHECK: 5308980208032766932
println("boom".hashValue)
// CHECK-NEXT: 6894346571320922064
println("zoom".hashValue)

// Unicode strings
// CHECK-NEXT: 3514641426931780352
println("ZOO≪M".hashValue)
// CHECK-NEXT: 7349636929305805742
println("moo≪m".hashValue)