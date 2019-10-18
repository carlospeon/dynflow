# frozen_string_literal: true
module Dynflow
  module Action::Timeouts
    Timeout = Algebrick.atom

    def process_timeout
      fail("Timeout exceeded.")
    end

    def schedule_timeout(seconds)
      plan_event(Timeout, seconds)
    end
 end
end
