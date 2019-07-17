require_relative 'report'

module ParallelReportPortal
  module Cucumber
    class Formatter
    
      def initialize(config)
        start_background_thread.priority = Thread.main.priority - 1 
        register_event_handlers(config)
      end
      
      private
      
      def report
        @report ||= Report.new(@start_time, background_queue)
      end
      
      def register_event_handlers(config)
        [:test_case_started, 
         :test_case_finished, 
         :test_step_started, 
         :test_step_finished].each do |event_name|
          config.on_event(event_name) do |event|
            report.public_send(event_name, event, ParallelReportPortal.clock)
          end
        end
        config.on_event :test_run_started,  &method(:handle_test_run_started )
        config.on_event :test_run_finished, &method(:handle_test_run_finished)
      end
      
      def handle_test_run_started(event)
        report.launch_started(ParallelReportPortal.clock)
      end
      
      def background_queue
        @background_queue ||= Queue.new
      end
      
      def start_background_thread
        @background_thread ||= Thread.new do
          loop do
            code = background_queue.pop
            code.call
          end
        end
      end
      
      def handle_test_run_finished(event)
        report.feature_finished(ParallelReportPortal.clock)
        report.launch_finished(ParallelReportPortal.clock)
        sleep 0.01 while !background_queue.empty? || background_queue.num_waiting == 0
        @background_thread.kill
      end
    
    end
  end
end