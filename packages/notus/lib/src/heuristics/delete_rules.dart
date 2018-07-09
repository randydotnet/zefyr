// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:quill_delta/quill_delta.dart';

/// A heuristic rule for delete operations.
abstract class DeleteRule {
  /// Constant constructor allows subclasses to declare constant constructors.
  const DeleteRule();

  /// Applies heuristic rule to a delete operation on a [document] and returns
  /// resulting [Delta].
  Delta apply(Delta document, int index, int length);
}

/// Fallback rule for delete operations which simply deletes specified text
/// range without any special handling.
class CatchAllDeleteRule extends DeleteRule {
  const CatchAllDeleteRule();

  @override
  Delta apply(Delta document, int index, int length) {
    return new Delta()
      ..retain(index)
      ..delete(length);
  }
}

/// Preserves line format when user deletes the line's line-break character
/// effectively merging it with the next line.
///
/// This rule makes sure to apply all style attributes of deleted line-break
/// to the next available line-break, which may reset any style attributes
/// already present there.
class PreserveLineStyleOnMergeRule extends DeleteRule {
  const PreserveLineStyleOnMergeRule();

  @override
  Delta apply(Delta document, int index, int length) {
    DeltaIterator iter = new DeltaIterator(document);
    iter.skip(index);
    final target = iter.next(1);
    if (target.data != '\n') return null;
    iter.skip(length - 1);
    final Delta result = new Delta()
      ..retain(index)
      ..delete(length);

    // Look for next line-break to apply the attributes
    while (iter.hasNext) {
      final op = iter.next();
      int lf = op.data.indexOf('\n');
      if (lf == -1) {
        result..retain(op.length);
        continue;
      }
      var attributes = _unsetAttributes(op.attributes);
      if (target.isNotPlain) {
        attributes ??= <String, dynamic>{};
        attributes.addAll(target.attributes);
      }
      result..retain(lf)..retain(1, attributes);
      break;
    }
    return result;
  }

  Map<String, dynamic> _unsetAttributes(Map<String, dynamic> attributes) {
    if (attributes == null) return null;
    return attributes.map((key, value) => new MapEntry(key, null));
  }
}