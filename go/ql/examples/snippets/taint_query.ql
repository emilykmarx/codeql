


/* Boilerplate for path queries */
import go
import taint_policy

signature class SourceSig extends DataFlow::Node;
signature class SinkSig extends DataFlow::Node;
module Config<SourceSig Source, SinkSig Sink> implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    source instanceof Source
  }

  predicate isSink(DataFlow::Node sink) {
    sink instanceof Sink
  }
}

module MyConfig = Config<WatchedVar, TaintedVar>;
module Flow = TaintTracking::Global<MyConfig>;
import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink)
and source != sink
select source.getNode().getStartColumn() as start, // For Delve to watch
source as source_, sink as sink_, "Fake" as fake

// TODO sep query for no sources

// PARTIAL QUERIES
int explorationLimit() { result = 5000 }
module MyPartialFlowFwd = Flow::FlowExplorationFwd<explorationLimit/0>;
module MyPartialFlowRev = Flow::FlowExplorationRev<explorationLimit/0>;

predicate adhocPartialFlowFwd(Callable c, MyPartialFlowFwd::PartialPathNode n, DataFlow::Node src, int dist) {
  exists(MyPartialFlowFwd::PartialPathNode source |
    MyPartialFlowFwd::partialFlow(source, n, dist) and
    src = source.getNode() and
    c = n.getNode().getEnclosingCallable()
  )
}

predicate adhocPartialFlowRev(Callable c, MyPartialFlowRev::PartialPathNode n, DataFlow::Node snk, int dist) {
  exists(MyPartialFlowRev::PartialPathNode sink |
    MyPartialFlowRev::partialFlow(n, sink, dist) and // note different param order for reverse
    snk = sink.getNode() and
    c = n.getNode().getEnclosingCallable()
  )
}

/*
from Callable c, MyPartialFlowFwd::PartialPathNode n, DataFlow::Node src, int dist
where MyConfig::isSource(src)
and adhocPartialFlowFwd(c, n, src, dist)
select src, n, c, n.getNode().getStartLine() as line order by line
*/

/*
from Callable c, MyPartialFlowRev::PartialPathNode n, DataFlow::Node snk, int dist
where Config::isSink(snk)
and adhocPartialFlowRev(c, n, snk, dist)
select n, snk, c, n.getNode().getStartLine() as line order by line
*/
