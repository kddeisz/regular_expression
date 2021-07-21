# frozen_string_literal: true

module RegularExpression
  # The scheduler tells us what order to generate our basic-blocks in.
  # Ideally it minimises jumps and optimises spatial locality.
  module Scheduler
    def self.schedule(cfg)
      schedule = []

      # Given a definition of 'ready to be scheduled' as a block that has yet
      # to be scheduled and where all the predecessors except itself have
      # already been scheduled.
      #
      # First we schedule the starting block.
      #
      # Then we keep scheduling additional blocks, each time taking the first
      # of these options that is available.
      #
      #   1) The most probable successor of the last block to be scheduled,
      #      adding all other succesor blocks yet to be scheduled to a deferred
      #      list.
      #
      #   2) The earliest deferred block that is ready to be scheduled.
      #
      #   3) The earliest deferred block (which allows for loops.)
      #
      # We stop scheduling when all blocks that have yet to be scheduled have
      # no predecessors (which allows for orphan blocks.)

      # Schedule the starting block.
      starting_block = cfg.start
      schedule.push(starting_block)

      deferred = []

      until schedule.size == cfg.blocks.values.size
        # The last scheduled block.
        just_scheduled = schedule.last

        # Successors of the last scheduled block that still need to be
        # scheduled.
        succs_to_schedule = just_scheduled.exits.reject { |e| schedule.include?(cfg.blocks[e.label]) }

        # Successors of the last scheduled block that are ready to be scheduled.
        sucss_ready = succs_to_schedule.select do |e|
          e_block = cfg.blocks[e.label]
          (e_block.preds - [e_block]).all? do |e_pred|
            schedule.include?(e_pred)
          end
        end

        # Are any successors of the last block that was scheduled themselves
        # ready to be scheduled?

        if sucss_ready.any?
          # Yes - the last block has successors ready to be scheduled.

          # Find the most probbale successor that is ready to be scheduled
          # (rule 1).
          most_probable_ready_succ = sucss_ready.max_by { |e| e.metadata[:probability] || 0.0 }
          most_probable_ready_succ_block = cfg.blocks[most_probable_ready_succ.label]
          raise if schedule.include?(most_probable_ready_succ_block)

          # Schedule it
          schedule.push most_probable_ready_succ_block

          # If we deferred it for later remove it.
          deferred.delete most_probable_ready_succ_block

          # Defer other successors that still need to be scheduled, less the
          # one that we just scheduled.
          deferred.push(*((succs_to_schedule - [most_probable_ready_succ]).map { |e| cfg.blocks[e.label] }))
        elsif deferred.any?
          # No - none of the successors of the last block are ready to be
          # scheduled. We do have deferred blocks.

          # Get the earliest deferred block that is ready to be scheduled
          # (rule 2).
          first_ready_deferred = deferred.find { |block| block.preds.all? { |pred| schedule.include?(pred) } }

          # If we didn't find one ready to be scheduled, just take the first
          # one (rule 3).
          first_ready_deferred ||= deferred.first

          deferred.delete first_ready_deferred
          raise if schedule.include?(first_ready_deferred)

          schedule.push first_ready_deferred
        elsif (cfg.blocks.values - schedule).all? { |a| a.preds.empty? }
          # No - none of the successors of the last block are ready to be
          # scheduled. We don't have deferred blocks. But it's ok because all
          # remaining blocks are orphans - so we can finish scheduling.
          break
        else
          # The scheduler is broken.
          raise
        end
      end

      schedule
    end

    def self.dump(cfg, schedule)
      io = StringIO.new
      schedule.each do |block|
        io.puts("#{block.name}:")
        block.exits.each { |exit| io.puts("    -> #{cfg.blocks[exit.label].name} #{exit.metadata.inspect}") }
      end
      io.string
    end
  end
end
