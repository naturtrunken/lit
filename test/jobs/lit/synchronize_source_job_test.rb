require 'test_helper'
require 'fakeweb'

# Applicable only in an ActiveJob-enabled environment (Rails 4.2+ or 4.0/4.1
# with additional gem)
if defined?(ActiveJob)
  module Lit
    class SynchronizeSourceJobTest < ActiveJob::TestCase
      include ActiveJob::TestHelper
      fixtures :all

      def setup
        after = 3.hours.ago
        after_str = after.strftime('%F %T')
        after_param = Rack::Utils.escape(after_str)
        @source = Source.first
        puts @source.incomming_localizations
        @source.update_column(:last_updated_at, after)
        localizations_addr = "http://testhost.com/lit/api/v1/localizations.json?after=#{after_param}"
        last_change_addr = 'http://testhost.com/lit/api/v1/last_change.json'
        FakeWeb.register_uri(:get, localizations_addr,
                             body: Localization.all.to_json)
        FakeWeb.register_uri(:get, last_change_addr,
                             body: { last_change: after_str }.to_json)
      end

      def do_job
        SynchronizeSourceJob.perform_later(@source)
      end

      test 'performs synchronization' do
        assert_performed_jobs(1) do
          assert_equal 0, @source.incomming_localizations.count
          do_job
          assert_equal 2, @source.incomming_localizations.count
        end
      end
    end
  end
end
