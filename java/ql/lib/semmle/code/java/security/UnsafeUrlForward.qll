import java
private import semmle.code.java.Jsf
private import semmle.code.java.dataflow.ExternalFlow
private import semmle.code.java.dataflow.FlowSources
private import semmle.code.java.dataflow.StringPrefixes
private import semmle.code.java.frameworks.javaee.ejb.EJBRestrictions
private import semmle.code.java.SpringResource

/** A sink for unsafe URL forward vulnerabilities. */
abstract class UnsafeUrlForwardSink extends DataFlow::Node { }

/** A sanitizer for unsafe URL forward vulnerabilities. */
abstract class UnsafeUrlForwardSanitizer extends DataFlow::Node { }

/** An argument to `getRequestDispatcher`. */
private class RequestDispatcherSink extends UnsafeUrlForwardSink {
  RequestDispatcherSink() {
    exists(MethodCall ma |
      ma.getMethod() instanceof GetRequestDispatcherMethod and
      ma.getArgument(0) = this.asExpr()
    )
  }
}

// TODO: look into `StaplerResponse.forward`, etc., and think about re-adding the MaD "request-forgery" sinks as a result
/** An argument to `new ModelAndView` or `ModelAndView.setViewName`. */
private class SpringModelAndViewSink extends UnsafeUrlForwardSink {
  SpringModelAndViewSink() {
    exists(ClassInstanceExpr cie |
      cie.getConstructedType() instanceof ModelAndView and
      cie.getArgument(0) = this.asExpr()
    )
    or
    exists(SpringModelAndViewSetViewNameCall smavsvnc | smavsvnc.getArgument(0) = this.asExpr())
  }
}

private class PrimitiveSanitizer extends UnsafeUrlForwardSanitizer {
  PrimitiveSanitizer() {
    this.getType() instanceof PrimitiveType or
    this.getType() instanceof BoxedType or
    this.getType() instanceof NumberType
  }
}

private class SanitizingPrefix extends InterestingPrefix {
  SanitizingPrefix() {
    not this.getStringValue().matches("/WEB-INF/%") and
    not this.getStringValue() = "forward:"
  }

  override int getOffset() { result = 0 }
}

private class FollowsSanitizingPrefix extends UnsafeUrlForwardSanitizer {
  FollowsSanitizingPrefix() { this.asExpr() = any(SanitizingPrefix fp).getAnAppendedExpression() }
}

private class ForwardPrefix extends InterestingPrefix {
  ForwardPrefix() { this.getStringValue() = "forward:" }

  override int getOffset() { result = 0 }
}

/**
 * An expression appended (perhaps indirectly) to `"forward:"`, and which
 * is reachable from a Spring entry point.
 */
private class SpringUrlForwardSink extends UnsafeUrlForwardSink {
  SpringUrlForwardSink() {
    any(SpringRequestMappingMethod sqmm).polyCalls*(this.getEnclosingCallable()) and
    this.asExpr() = any(ForwardPrefix fp).getAnAppendedExpression()
  }
}
