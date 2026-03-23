module RedmineHelpdesk
  module MailerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      def helpdesk_issue_edit_to_owner(issue, journal, owner_email, cc_users = nil)
        redmine_headers 'Project' => issue.project.identifier,
                        'Issue-Id' => issue.id,
                        'Issue-Author' => issue.author.login,
                        'Issue-Tracker' => issue.tracker
        redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to

        message_id journal
        references issue

        @author = journal.user

        begin
          f = CustomField.find_by_name('helpdesk-reply-separator')
          reply_separator = issue.project.custom_value_for(f).try(:value)
          if reply_separator.present? && journal.notes.present?
            @journal = journal.dup
            @journal.notes = journal.notes.gsub(/#{Regexp.escape(reply_separator)}.*/m, '')
          else
            @journal = journal
          end
        rescue => e
          Rails.logger.error "Helpdesk owner mail: reply separator processing failed: #{e.message}"
          @journal = journal
        end

        s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
        s += "(#{issue.status.name}) " if journal.new_value_for('status_id') && Setting.show_status_changes_in_mail_subject?
        s += issue.subject

        @issue = issue
        @user = journal.user
        @journal_details = journal.visible_details
        @issue_url = url_for(
          controller: 'issues',
          action: 'show',
          id: issue,
          anchor: "change-#{journal.id}"
        )

        mail(
          to: owner_email,
          cc: Array(cc_users).flatten.compact.reject(&:blank?).presence,
          subject: s
        )
      end
    end
  end
end

Mailer.send(:include, ::RedmineHelpdesk::MailerPatch)