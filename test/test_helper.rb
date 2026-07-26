ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "support/auth_test_helper"
OmniAuth.config.test_mode = true

# test-prof: 環境変数を付けたときだけ計測が走る（普段の実行には影響しない）。
#   FPROF=1 bin/rails test              # factory 呼び出し回数
#   EVENT_PROF=sql.active_record ...    # SQL に費やした時間の多いテスト
#   TEST_PROF_REPORT=... など詳細は https://test-prof.evilmartians.io/
require "test-prof" if ENV["FPROF"] || ENV["EVENT_PROF"] || ENV["TEST_PROF_REPORT"]

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # factory_bot: create(:user) 等を直接呼べるように（定義は test/factories.rb）
    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include AuthTestHelper
end
