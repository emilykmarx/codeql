/**
 * @name Uncontrolled data used in path expression
 * @description Resolving externally-provided content URIs without validation can allow an attacker
 *              to access unexpected resources.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id java/android/unsafe-content-uri-resolution
 * @tags security
 *     external/cwe/cwe-441
 *     external/cwe/cwe-610
 */

import java
import UnsafeContentUriResolutionQuery
import DataFlow::PathGraph

from DataFlow::PathNode src, DataFlow::PathNode sink
where any(UnsafeContentResolutionConf c).hasFlowPath(src, sink)
select sink.getNode(), src, sink,
  "This $@ flows to a ContentResolver method that resolves a URI. The result is then used in a write operation.",
  src.getNode(), "user input"
