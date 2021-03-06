require 'jira'

module ErrbitJiraPlugin
  class IssueTracker < ErrbitPlugin::IssueTracker
    LABEL = 'jira'.freeze

    NOTE = 'Please configure Jira by entering the information below.'.freeze

    FIELDS = {
      base_url: {
        label: 'Jira URL without trailing slash',
        placeholder: 'https://jira.example.org'
      },
      context_path: {
        optional: true,
        label: 'Context Path (Just "/" if empty otherwise with leading slash)',
        placeholder: '/jira'
      },
      username: {
        label: 'Username',
        placeholder: 'johndoe'
      },
      password: {
        label: 'Password',
        placeholder: 'p@assW0rd'
      },
      project_id: {
        label: 'Project Key',
        placeholder: 'The project Key where the issue will be created'
      },
      issue_priority: {
        label: 'Priority',
        placeholder: 'Normal'
      },
      issue_type: {
        label: 'Issue type',
        placeholder: 'The issue type from Jira only numeric'
      }

    }.freeze

    def self.label
      LABEL
    end

    def self.note
      NOTE
    end

    def self.fields
      FIELDS
    end

    def self.icons
      @icons ||= {
        create: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_create.png')
        ],
        goto: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_goto.png')
        ],
        inactive: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_inactive.png')
        ]
      }
    end

    def self.body_template
      @body_template ||= ERB.new(File.read(
                                   File.join(
                                     ErrbitJiraPlugin.root, 'views', 'jira_issues_body.txt.erb'
                                   )
      ))
    end

    def configured?
      params['project_id'].present?
    end

    def errors
      errors = []
      if self.class.fields.detect { |f| options[f[0]].blank? }
        errors << [:base, 'You must specify all non optional values!']
      end
      errors
    end

    def comments_allowed?
      false
    end

    def jira_options
      {
        username: params['username'],
        password: params['password'],
        site: params['base_url'],
        auth_type: :basic,
        context_path: context_path
      }
    end

    def create_issue(title, body, problem, user: {})
      client = JIRA::Client.new(jira_options)
      project = client.Project.find(params['project_id'])

      issue_fields = {
        'fields' => {
          'summary' => title,
          'description' => body,
          'environment' => problem.environment,
          'project' => { 'id' => project.id },
          'issuetype' => { 'id' => params['issue_type'] },
          'priority' => { 'name' => params['issue_priority'] }
        }
      }

      jira_issue = client.Issue.build

      jira_issue.save(issue_fields)

      jira_url(params['project_id'])
    rescue JIRA::HTTPError
      raise ErrbitJiraPlugin::IssueError, 'Could not create an issue with Jira.  Please check your credentials.'
    end

    def jira_url(project_id)
      "#{params['base_url']}#{params['context_path']}browse/#{project_id}"
    end

    def url
      params['base_url']
    end

    private

    def context_path
      if params['context_path'] == '/'
        ''
      else
        params['context_path']
      end
    end

    def params
      options
    end
  end
end
