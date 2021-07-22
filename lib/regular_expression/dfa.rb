# frozen_string_literal: true

module RegularExpression
  module DFA
    class << self
      # This method converts a non-deterministic finite automata into a
      # deterministic finite automata. The best link I could find that describes
      # the general approach taken here is here:
      #
      #   https://www.geeksforgeeks.org/conversion-from-nfa-to-dfa/
      #
      # The general idea is to walk the state machine and make it such that
      # for any given state and input you deterministically know which state the
      # machine should transition to. In effect, this means we're removing all
      # epsilon transitions.
      def build(nfa_start_state)
        nfa_start_states = follow_epsilon_transitions_from([nfa_start_state])
        worklist = [nfa_start_states]

        # dfa_states is a hash that points from a set of states in the NFA to the
        # new state in the DFA.
        dfa_states = {
          nfa_start_states => NFA::StartState.new(nfa_start_states.map(&:label).join(","))
        }

        until worklist.empty?
          current_nfa_states = worklist.pop

          transitions = []

          # First, we're going to build up a list of transitions that exit out
          # of the current set of states that we're looking at. We'll initialize
          # them to an empty array which is going to eventually represent the
          # set of states that that transition transitions to.
          current_nfa_states.flat_map(&:transitions).each do |transition|
            unless transition.is_a?(NFA::Transition::Epsilon)
              transitions << transition
            end
          end

          # Second, we're going to apply each of those transitions to each of
          # the states in our current set to determine where we could end up
          # for any of the transitions.
          transitions.each do |transition|
            next_nfa_states = []

            current_nfa_states.flat_map(&:transitions).each do |current_transition|
              next_nfa_states << current_transition.state if transition.matches?(current_transition)
            end

            # Now that we have a full set of states that this transition goes
            # to, we're going to create a transition in our DFA that represents
            # this transition.
            next_nfa_states = follow_epsilon_transitions_from(next_nfa_states)

            unless dfa_states.key?(next_nfa_states)
              # Make sure we check the next states.
              worklist << next_nfa_states
            end

            # If any of the NFA states is a finish state, the DFA state
            # should be too.
            state_class =
              if next_nfa_states.any? { |state| state.is_a?(NFA::FinishState) }
                NFA::FinishState
              else
                NFA::State
              end

            new_state = (dfa_states[next_nfa_states] ||= state_class.new(next_nfa_states.map(&:label).join(",")))
            unless dfa_states[current_nfa_states].transitions.any? { |t| t.matches?(transition) }
              dfa_states[current_nfa_states].add_transition(transition.copy(new_state))
            end
          end
        end

        # Return the start state of the new DFA.
        dfa_states[nfa_start_states]
      end

      private

      # Get the set of states that correspond to the given set of states but
      # walked through any epsilon transitions. So for example if we have the
      # following NFA which represents the a?a?b language:
      #
      # ─> (1) ─a─> (2) ─a─> (3) ─b─> [4]
      #     └───ε-──^└───ε-───^
      #
      # Then if you passed [1] into here we would return [1,2,3].
      def follow_epsilon_transitions_from(states)
        next_states = [*states]
        index = 0

        while index < next_states.length
          next_states[index].transitions.each do |transition|
            if transition.is_a?(NFA::Transition::Epsilon) && !next_states.include?(transition.state)
              next_states << transition.state
            end
          end

          index += 1
        end

        next_states
      end
    end
  end
end
