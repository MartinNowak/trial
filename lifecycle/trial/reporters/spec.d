module trial.reporters.spec;

import std.stdio;
import std.array;
import std.conv;
import std.datetime;

import trial.interfaces;
import trial.reporters.writer;

class SpecReporter : ITestCaseLifecycleListener, ISuiteLifecycleListener, IStepLifecycleListener {
  enum Type {
    none,
    success,
    step,
    failure,
    testBegin,
    testEnd,
    emptyLine
  }

  protected {
    int indents;
    int stepIndents;

    int tests;
    int failedTests = 0;
    int currentStep = 0;

    string currentTestName;

    SysTime beginTime;
    ReportWriter writer;
  }

  private {
    immutable string ok = "✓";
    immutable string current = "┌";
    immutable string line = "│";
    immutable string result = "└";
  }

  this() {
    writer = defaultWriter;
  }

  this(ReportWriter writer) {
    this.writer = writer;
  }

  private {
    string indentation(int cnt) pure {
      return "  ".replicate(cnt);
    }
  }

  void write(Type t)(string text = "", int spaces = 0) {
    switch(t) {
      case Type.emptyLine:
        writer.writeln("");
        break;

      case Type.success:
        writer.write(ok, ReportWriter.Context.success);
        writer.write(" " ~ text, ReportWriter.Context.inactive);
        break;

      case Type.failure:
        writer.write(failedTests.to!string ~ ") " ~ text, ReportWriter.Context.danger);
        break;

      case Type.testBegin:
          writer.write(indentation(spaces));
          writer.write(current, ReportWriter.Context.info);
          writer.write(" " ~ text, ReportWriter.Context.inactive);
        break;

      case Type.testEnd:
        writer.write(indentation(spaces));
        writer.write(result ~ " " ~ text, ReportWriter.Context.info);
        break;

      case Type.step:
        writer.write(indentation(spaces));
        writer.write(line, ReportWriter.Context.info);
        writer.write(indentation(stepIndents));
        writer.write(" " ~ text, ReportWriter.Context.inactive);
        break;

      default:
        writer.write(indentation(spaces) ~ text);
    }
  }

  void begin(ref SuiteResult suite) {
    indents++;
    write!(Type.emptyLine);
    write!(Type.none)(suite.name, indents);
    write!(Type.emptyLine);
  }

  void end(ref SuiteResult suite) {
    indents--;
  }

  void begin(string suite, ref TestResult test) {
    indents++;
    tests++;
    currentStep = 0;
    stepIndents = 0;
    currentTestName = test.name;
  }

  void end(string suite, ref TestResult test) {
    if(currentStep == 0) {
      writer.write(indentation(indents));

      if(test.status == TestResult.Status.success) {
        write!(Type.success)(test.name, indents);
      }

      if(test.status == TestResult.Status.failure) {
        write!(Type.failure)(test.name, indents);
        failedTests++;
      }
    } else {
      write!(Type.testEnd)("", indents);

      if(test.status == TestResult.Status.success) {
        write!(Type.success)("Success");
      }

      if(test.status == TestResult.Status.failure) {
        write!(Type.failure)("Failure");
        failedTests++;
      }
    }
    write!(Type.emptyLine);

    indents--;
  }

  void begin(string suite, string test, ref StepResult step) {
    if(currentStep == 0) {
      write!(Type.testBegin)(currentTestName, indents);
      write!(Type.emptyLine);
    }

    stepIndents++;
    write!(Type.step)(step.name, indents);
    write!(Type.emptyLine);
    currentStep++;
  }

  void end(string suite, string test, ref StepResult step) {
    stepIndents--;
  }
}

version(unittest) {
  import fluent.asserts;
}

@("it should print a success test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  reporter.begin(suite);

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    ✓ some test\n");
}

@("it should print two success tests")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test1 = new TestResult("some test");
  test1.status = TestResult.Status.success;

  auto test2 = new TestResult("other test");
  test2.status = TestResult.Status.success;

  reporter.begin(suite);

  reporter.begin("some suite", test1);
  reporter.end("some suite", test1);

  reporter.begin("some suite", test2);
  reporter.end("some suite", test2);

  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    ✓ some test\n");
  writer.buffer.should.contain("\n    ✓ other test\n");
}

@("it should print a failing test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");

  test.status = TestResult.Status.failure;
  test.throwable = new Exception("Random failure");

  reporter.begin(suite);
  reporter.begin("some suite", test);
  reporter.end("some suite", test);
  reporter.end(suite);

  writer.buffer.should.contain("\n  some suite\n");
  writer.buffer.should.contain("\n    0) some test\n");
}

@("it should format the steps for a success test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.success;

  auto step = new StepResult();
  step.name = "some step";

  reporter.begin(suite);
  reporter.begin("some suite", test);

  reporter.begin("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);

  reporter.end("some suite", test);

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
                             "  some suite\n" ~
                             "    ┌ some test\n" ~
                             "    │   some step\n" ~
                             "    │     some step\n" ~
                             "    │   some step\n" ~
                             "    └ ✓ Success\n" ~
                             "    ✓ some test\n");
}


@("it should format the steps for a failing test")
unittest {
  auto writer = new BufferedWriter;
  auto reporter = new SpecReporter(writer);

  auto suite = SuiteResult("some suite");
  auto test = new TestResult("some test");
  test.status = TestResult.Status.failure;

  auto step = new StepResult();
  step.name = "some step";

  reporter.begin(suite);
  reporter.begin("some suite", test);

  reporter.begin("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.end("some suite", "some test", step);
  reporter.begin("some suite", "some test", step);
  reporter.end("some suite", "some test", step);

  reporter.end("some suite", test);

  reporter.begin("some suite", test);
  reporter.end("some suite", test);

  reporter.end(suite);

  writer.buffer.should.equal("\n" ~
                             "  some suite\n" ~
                             "    ┌ some test\n" ~
                             "    │   some step\n" ~
                             "    │     some step\n" ~
                             "    │   some step\n" ~
                             "    └ 0) Failure\n" ~
                             "    1) some test\n");
}
