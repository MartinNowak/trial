/++
  A module containing the single threaded runner

  Copyright: © 2017 Szabo Bogdan
  License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
  Authors: Szabo Bogdan
+/
module trial.executor.single;

public import trial.interfaces;
import trial.runner;
import std.datetime;
import trial.step;
import trial.stackresult;

/**
The default test executor runs test in sequential order in a single thread
*/
class DefaultExecutor : ITestExecutor, IStepLifecycleListener, IAttachmentListener
{
  private
  {
    SuiteResult suiteResult;
    TestResult testResult;
    StepResult currentStep;
    StepResult[] stepStack;
  }

  this() {
    suiteResult = SuiteResult("unknown");
  }

  /// Called when an attachment is ready
  void attach(ref const Attachment attachment) {
    if(currentStep is null) {
      suiteResult.attachments ~= Attachment(attachment.name, attachment.file, attachment.mime);
      return;
    }

    currentStep.attachments ~= Attachment(attachment.name, attachment.file, attachment.mime);
  }

  /// Add the step result and update the other listeners on every step
  void begin(string suite, string test, ref StepResult step)
  {
    currentStep.steps ~= step;
    stepStack ~= currentStep;
    currentStep = step;
    LifeCycleListeners.instance.update();
  }

  /// Update the other listeners on every step
  void end(string suite, string test, ref StepResult step)
  {
    currentStep = stepStack[stepStack.length - 1];
    stepStack = stepStack[0 .. $ - 1];
    LifeCycleListeners.instance.update();
  }

  /// It does nothing
  SuiteResult[] beginExecution(ref const(TestCase)[])
  {
    return [];
  }

  /// Return the result for the last executed suite
  SuiteResult[] endExecution()
  {
    if (suiteResult.begin == SysTime.fromUnixTime(0))
    {
      return [];
    }

    LifeCycleListeners.instance.update();
    LifeCycleListeners.instance.end(suiteResult);
    return [suiteResult];
  }

  private
  {
    void createTestResult(const(TestCase) testCase)
    {
      testResult = testCase.toTestResult;
      testResult.status = TestResult.Status.started;
      currentStep = testResult;

      stepStack = [];

      Step.suite = testCase.suiteName;
      Step.test = testCase.name;

      LifeCycleListeners.instance.begin(testCase.suiteName, testResult);

      try
      {
        testCase.func();
        testResult.status = TestResult.Status.success;
      }
      catch (Throwable t)
      {
        testResult.status = TestResult.Status.failure;
        testResult.throwable = t.toTestException;
      }

      testResult.end = Clock.currTime;
      LifeCycleListeners.instance.end(testCase.suiteName, testResult);
    }
  }

  /// Execute a test case
  SuiteResult[] execute(ref const(TestCase) testCase)
  {
    SuiteResult[] result;
    LifeCycleListeners.instance.update();

    if (suiteResult.name != testCase.suiteName)
    {
      if (suiteResult.begin != SysTime.fromUnixTime(0))
      {
        suiteResult.end = Clock.currTime;
        LifeCycleListeners.instance.end(suiteResult);
        result = [suiteResult];
      }

      suiteResult = SuiteResult(testCase.suiteName, Clock.currTime, Clock.currTime);
      LifeCycleListeners.instance.begin(suiteResult);
    }

    createTestResult(testCase);
    suiteResult.tests ~= testResult;
    currentStep = null;
    LifeCycleListeners.instance.update();

    return result;
  }
}
