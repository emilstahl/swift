//===--- Index.swift - A position in a CollectionType ---------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
//  ForwardIndexType, BidirectionalIndexType, and RandomAccessIndexType
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//===--- Dispatching advance and distance functions -----------------------===//
// These generic functions are for user consumption; they dispatch to the
// appropriate implementation for T.

/// Measure the distance between `start` and `end`.
///
/// If `T` models `RandomAccessIndexType`, requires that `start` and `end` are
/// part of the same sequence, and executes in O(1).
///
/// Otherwise, requires that `end` is reachable from `start` by
/// incrementation, and executes in O(N), where N is the function's
/// result.
public func distance<T: ForwardIndexType>(start: T, end: T) -> T.Distance {
  return start~>_distanceTo(end)
}

/// Return the result of advancing `start` by `n` positions.  If `T`
/// models `RandomAccessIndexType`, executes in O(1).  Otherwise,
/// executes in O(`abs(n)`).  If `T` does not model
/// `BidirectionalIndexType`, requires that `n` is non-negative.
///
/// `advance(i, n)` is a synonym for `i++n'
public func advance<T: ForwardIndexType>(start: T, n: T.Distance) -> T {
  return start~>_advance(n)
}

/// Return the result of advancing start by `n` positions, or until it
/// equals `end`.  If `T` models `RandomAccessIndexType`, executes in
/// O(1).  Otherwise, executes in O(`abs(n)`).  If `T` does not model
/// `BidirectionalIndexType`, requires that `n` is non-negative.
public func advance<T: ForwardIndexType>(start: T, n: T.Distance, end: T) -> T {
  return start~>_advance(n, end)
}

/// Operation tags for distance and advance
///
/// Operation tags allow us to use a single operator (~>) for
/// dispatching every generic function with a default implementation.
/// Only authors of specialized distance implementations need to touch
/// this tag.
public struct _Distance {}
public func _distanceTo<I>(end: I) -> (_Distance, (I)) {
  return (_Distance(), (end))
}

public struct _Advance {}
public func _advance<D>(n: D) -> (_Advance, (D)) {
  return (_Advance(), (n: n))
}
public func _advance<D, I>(n: D, end: I) -> (_Advance, (D, I)) {
  return (_Advance(), (n, end))
}

//===----------------------------------------------------------------------===//
//===--- ForwardIndexType -------------------------------------------------===//

// Protocols with default implementations are broken into two parts, a
// base and a more-refined part.  From the user's point-of-view,
// however, _ForwardIndexType and ForwardIndexType should look like a single
// protocol.  This technique gets used throughout the standard library
// to break otherwise-cyclic protocol dependencies, which the compiler
// isn't yet smart enough to handle.

/// This protocol is an implementation detail of `ForwardIndexType`; do
/// not use it directly.
///
/// Its requirements are inherited by `ForwardIndexType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _Incrementable : Equatable {
  /// Return the next consecutive value in a discrete sequence of
  /// `Self` values
  ///
  /// Requires: `self` has a well-defined successor.
  func successor() -> Self
}

//===----------------------------------------------------------------------===//
// A dummy type that we can use when we /don't/ want to create an
// ambiguity indexing Range<T> outside a generic context.  See the
// implementation of Range for details.
public struct _DisabledRangeIndex_ {
  init() {
    _sanityCheckFailure("Nobody should ever create one.")
  }
}

//===----------------------------------------------------------------------===//

/// This protocol is an implementation detail of `ForwardIndexType`; do
/// not use it directly.
///
/// Its requirements are inherited by `ForwardIndexType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _ForwardIndexType : _Incrementable {
  /// A type that can represent the number of steps between pairs of
  /// `Self` values where one value is reachable from the other.
  ///
  /// Reachability is defined by the ability to produce one value from
  /// the other via zero or more applications of `successor`.
  typealias Distance : _SignedIntegerType = Int

  // See the implementation of Range for an explanation of this
  // associated type
  typealias _DisabledRangeIndex = _DisabledRangeIndex_
}

@transparent
public prefix func ++ <T : _Incrementable> (inout x: T) -> T {
  x = x.successor()
  return x
}

@transparent
public postfix func ++ <T : _Incrementable> (inout x: T) -> T {
  var ret = x
  x = x.successor()
  return ret
}

/// Represents a discrete value in a series, where a value's
/// successor, if any, is reachable by applying the value's
/// `successor()` method.
public protocol ForwardIndexType : _ForwardIndexType {
  // This requirement allows generic distance() to find default
  // implementations.  Only the author of F and the author of a
  // refinement of F having a non-default distance implementation need
  // to know about it.  These refinements are expected to be rare
  // (which is why defaulted requirements are a win)

  // Do not use these operators directly; call distance(start, end)
  // and advance(start, n) instead
  func ~> (start:Self, _ : (_Distance, Self)) -> Distance
  func ~> (start:Self, _ : (_Advance, Distance)) -> Self
  func ~> (start:Self, _ : (_Advance, (Distance, Self))) -> Self
}

// advance and distance implementations

/// Do not use this operator directly; call distance(start, end) instead
public
func ~> <T: _ForwardIndexType>(start:T, rest: (_Distance, T)) -> T.Distance {
  var p = start
  var count: T.Distance = 0
  let end = rest.1
  while p != end {
    ++count
    ++p
  }
  return count
}

/// Do not use this operator directly; call advance(start, n) instead
@transparent
public func ~> <T: _ForwardIndexType>(
  start: T, rest: (_Advance, T.Distance)
) -> T {
  let n = rest.1
  return _advanceForward(start, n)
}

internal
func _advanceForward<T: _ForwardIndexType>(start: T, n: T.Distance) -> T {
  _precondition(n >= 0,
      "Only BidirectionalIndexType can be advanced by a negative amount")
  var p = start
  for var i: T.Distance = 0; i != n; ++i {
    ++p
  }
  return p
}

/// Do not use this operator directly; call advance(start, n, end) instead
@transparent
public func ~> <T: _ForwardIndexType>(
  start:T, rest: ( _Advance, (T.Distance, T))
) -> T {
  return _advanceForward(start, rest.1.0, rest.1.1)
}

internal
func _advanceForward<T: _ForwardIndexType>(
  start: T, n: T.Distance, end: T
) -> T {
  _precondition(n >= 0,
      "Only BidirectionalIndexType can be advanced by a negative amount")
  var p = start
  for var i: T.Distance = 0; i != n && p != end; ++i {
    ++p
  }
  return p
}

//===----------------------------------------------------------------------===//
//===--- BidirectionalIndexType -------------------------------------------===//
/// This protocol is an implementation detail of `BidirectionalIndexType`; do
/// not use it directly.
///
/// Its requirements are inherited by `BidirectionalIndexType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _BidirectionalIndexType : _ForwardIndexType {
  /// Return the previous consecutive value in a discrete sequence.
  ///
  /// If `self` has a well-defined successor,
  /// `self.successor().predecessor() == self`.  If `self` has a
  /// well-defined predecessor, `self.predecessor().successor() ==
  /// self`.
  ///
  /// Requires: `self` has a well-defined predecessor.
  func predecessor() -> Self
}

/// An *index* that can step backwards via application of its
/// `predecessor()` method.
public protocol BidirectionalIndexType 
  : ForwardIndexType, _BidirectionalIndexType {}

@transparent
public prefix func -- <T: _BidirectionalIndexType> (inout x: T) -> T {
  x = x.predecessor()
  return x
}


@transparent
public postfix func -- <T: _BidirectionalIndexType> (inout x: T) -> T {
  var ret = x
  x = x.predecessor()
  return ret
}

// advance implementation

/// Do not use this operator directly; call advance(start, n) instead
@transparent
public func ~> <T: _BidirectionalIndexType>(
  start:T , rest: (_Advance, T.Distance)
) -> T {
  let n = rest.1
  if n >= 0 {
    return _advanceForward(start, n)
  }
  var p = start
  for var i: T.Distance = n; i != 0; ++i {
    --p
  }
  return p
}

/// Do not use this operator directly; call advance(start, n, end) instead
@transparent
public func ~> <T: _BidirectionalIndexType>(
  start:T, rest: (_Advance, (T.Distance, T))
) -> T {
  let n = rest.1.0
  let end = rest.1.1

  if n >= 0 {
    return _advanceForward(start, n, end)
  }
  var p = start
  for var i: T.Distance = n; i != 0 && p != end; ++i {
    --p
  }
  return p
}

//===----------------------------------------------------------------------===//
//===--- RandomAccessIndexType --------------------------------------------===//
/// This protocol is an implementation detail of `RandomAccessIndexType`; do
/// not use it directly.
///
/// Its requirements are inherited by `RandomAccessIndexType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _RandomAccessIndexType : _BidirectionalIndexType, Strideable {
  /// Return the minimum number of applications of `successor` or
  /// `predecessor` required to reach `other` from `self`.
  ///
  /// Complexity: O(1).
  ///
  /// Axioms::
  /// 
  ///   x.distanceTo(x.successor())) == 1
  ///   x.distanceTo(x.predecessor())) == -1
  ///   x.advancedBy(x.distanceTo(y)) == y
  func distanceTo(other: Self) -> Distance

  /// Return `self` offset by `n` steps.
  ///
  /// :returns: If `n > 0`, the result of applying `successor` to
  /// `self` `n` times.  If `n < 0`, the result of applying
  /// `predecessor` to `self` `n` times. Otherwise, `self`.
  ///
  /// Complexity: O(1)
  ///
  /// Axioms::
  ///
  ///   x.advancedBy(0) == x
  ///   x.advancedBy(1) == x.successor()
  ///   x.advancedBy(-1) == x.predecessor()
  ///   x.distanceTo(x.advancedBy(m)) == m
  func advancedBy(n: Distance) -> Self
}

/// An *index* that can be offset by an arbitrary number of positions,
/// and can measure the distance to any reachable value, in O(1).
public protocol RandomAccessIndexType
  : BidirectionalIndexType, _RandomAccessIndexType {
  /* typealias Distance : IntegerArithmeticType*/
}

// advance and distance implementations

/// Do not use this operator directly; call distance(start, end) instead
@transparent
public func ~> <T: _RandomAccessIndexType>(start:T, rest:(_Distance, (T)))
-> T.Distance {
  let end = rest.1
  return start.distanceTo(end)
}

/// Do not use this operator directly; call advance(start, n) instead
@transparent
public func ~> <T: _RandomAccessIndexType>(
  start:T, rest:(_Advance, (T.Distance))
) -> T {
  let n = rest.1
  return start.advancedBy(n)
}

/// Do not use this operator directly; call advance(start, n, end) instead
@transparent
public func ~> <T: _RandomAccessIndexType>(
  start:T, rest:(_Advance, (T.Distance, T))
) -> T {
  let n = rest.1.0
  let end = rest.1.1

  let d = start.distanceTo(end)
  var amount = n
  if n < 0 {
    if d < 0 && d > n {
      return end
    }
  }
  else {
    if d > 0 && d < n {
      return end
    }
  }
  return start.advancedBy(amount)
}
