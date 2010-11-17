new JSAN('..').use('Test.More');

// There is a bug where incorrect plan numbers are not detected!
plan({tests: 1});

Class('FooBar', {});

ok(FooBar, 'FooBar was created by Joose');

