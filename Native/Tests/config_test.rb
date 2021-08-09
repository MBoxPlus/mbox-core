require 'test-utils/mbox-tests'

class Config < MBoxTests
  def test_list_empty
    _, stdout, _ = mbox!("config")
    assert_equal({}, JSON.parse(stdout))
  end

  def test_nonexists
    mbox(%w"config a 1", code: 254, stderr: /The key path `a` is invalid/)
  end

  def test_set_dev_root
    mbox!(%w"config core.dev-root a/b/c")
    mbox!(%w"config core.dev-root", stdout: "core.dev-root: a/b/c")
  end
end