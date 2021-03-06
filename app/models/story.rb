class Story < Issue
    unloadable

    def self.product_backlog(project, limit=nil)
      return Story.find(:all,
            :order => 'position ASC',
            :conditions => [
                "parent_id is NULL and project_id = ? and tracker_id in (?) and fixed_version_id is NULL", #and status_id in (?)",
                project.id, Story.trackers #, IssueStatus.find(:all, :conditions => ["is_closed = ?", false]).collect {|s| "#{s.id}" }
                ],
            :limit => limit)
    end

    named_scope :sprint_backlog, lambda { |sprint|
        {
            :order => 'position ASC',
            :conditions => [
                "parent_id is NULL and tracker_id in (?) and fixed_version_id = ?",
                Story.trackers, sprint.id
                ]
        }
    }
    
    def self.trackers
        trackers = Setting.plugin_redmine_backlogs[:story_trackers]
        return [] if trackers == '' or trackers.nil?

        return trackers.map { |tracker| Integer(tracker) }
    end

    def move_after(id)
      insert_at 0 unless in_list?

      begin
        prev = self.class.find(id)
      rescue ActiveRecord::RecordNotFound
        prev = nil
      end

      # if it's the first story, move it to the 1st position
      if !prev
        move_to_top

      # if its predecessor has no position (shouldn't happen), make it
      # the last story
      elsif !prev.in_list?
        move_to_bottom

      # there's a valid predecessor
      else
        my_pos = send(position_column).to_i
        prev_pos = prev.send(position_column).to_i
        insert_at(my_pos == 0 || my_pos > prev_pos ? prev_pos + 1 : prev_pos)
      end
    end

    def set_points(p)
        self.init_journal(User.current)

        if p.nil? || p == '' || p == '-'
            self.update_attribute(:story_points, nil)
            return
        end

        if p.downcase == 's'
            self.update_attribute(:story_points, 0)
            return
        end

        p = Integer(p)
        if p >= 0
            self.update_attribute(:story_points, p)
            return
        end
    end

    def points_display(notsized='-')
        # For reasons I have yet to uncover, activerecord will
        # sometimes return numbers as Fixnums that lack the nil?
        # method. Comparing to nil should be safe.
        return notsized if story_points == nil
        return 'S' if story_points == 0
        return story_points.to_s
    end

    def task_status
        closed = 0
        open = 0
        self.descendants.each {|task|
            if task.closed?
                closed += 1
            else
                open += 1
            end
        }
        return {:open => open, :closed => closed}
    end
end
