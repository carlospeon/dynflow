module Dynflow
  module Executors
    class Parallel < Abstract
      class Worker < MicroActor
        def initialize(pool)
          super(pool.logger, pool)
        end

        private

        def delayed_initialize(pool)
          @pool = pool
        end

        def on_message(message)
          match message,
                Work::Step.(step: ~any) | Work::Event.(step: ~any, event: Event.(event: ~any)) >-> step, event do
                  step.execute event
                end,
                Work::Finalize.(~any, any) >-> sequential_manager do
                  sequential_manager.finalize
                end
          @pool << WorkerDone[work: message, worker: self]
        end
      end
    end
  end
end