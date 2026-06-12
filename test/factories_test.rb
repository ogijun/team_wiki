require "test_helper"

# 全 factory（trait 込み）が valid なレコードを生成できることを保証する。
# スキーマ変更で factory が壊れたらここで即検知する。
class FactoriesTest < ActiveSupport::TestCase
  test "all factories and traits are lintable" do
    factories = FactoryBot.factories.flat_map do |factory|
      [ factory ] + factory.definition.defined_traits.map { |t| [ factory.name, t.name ] }
    end
    FactoryBot.lint(traits: true)
    assert factories.any?
  end
end
