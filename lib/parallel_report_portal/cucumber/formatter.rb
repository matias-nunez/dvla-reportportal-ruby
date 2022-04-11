require_relative 'report'
require_relative '../clock'
require_relative '../configuration'
require_relative '../file_utils'
require_relative '../http'
require_relative '../version'
require_relative '../../parallel_report_portal'

module ParallelReportPortal
  module Cucumber
    # Formatter supporting the Cucumber formatter API.
    # This is the class which does the heavy-lifting by
    # integrating with cucumber.
    class Formatter

      CucumberMessagesVersion=[4,0,0]

      # Create a new formatter instance
      # 
      # @param [Cucumber::Configuration] cucumber_config the cucumber configuration environment
      def initialize(cucumber_config)
        @ast_lookup = if (::Cucumber::VERSION.split('.').map(&:to_i) <=> CucumberMessagesVersion) > 0
          require 'cucumber/formatter/ast_lookup'
          ::Cucumber::Formatter::AstLookup.new(cucumber_config)
        else
          nil
        end
        start_background_thread.priority = Thread.main.priority + 1 
        register_event_handlers(cucumber_config)
      end

      private

      def report
        @report ||= Report.new(@ast_lookup)
      end

      def register_event_handlers(config)
        [:test_case_started, 
         :test_case_finished, 
         :test_step_started, 
         :test_step_finished].each do |event_name|
          config.on_event(event_name) do |event|
            background_queue << -> { report.public_send(event_name, event, ParallelReportPortal.clock) }
          end
        end
        config.on_event :test_run_started,  &method(:handle_test_run_started )
        config.on_event :test_run_finished, &method(:handle_test_run_finished)
      end
      
      def handle_test_run_started(event)
        background_queue << proc { report.launch_started(ParallelReportPortal.clock) }
      end
      
      def background_queue
        @background_queue ||= Queue.new
      end
      
      def start_background_thread
        @background_thread ||= Thread.new do
          loop do
            code = background_queue.shift
            code.call
          end
        end
      end
      
      def handle_test_run_finished(event)
        background_queue << proc do
          report.feature_finished(ParallelReportPortal.clock)
          report.launch_finished(ParallelReportPortal.clock)
        end
        sleep 0.01 while !background_queue.empty? || background_queue.num_waiting == 0
        @background_thread.kill
      end
    
    end
  end
end
