class CatchOauthErrors
    include CfMysqlBroker::Application.routes.url_helpers

  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue CF::UAA::InvalidToken, CF::UAA::TargetError => e
      puts "RESCUED"
      puts e.class
      puts e.message
      puts e.backtrace
      [302, {'Location' => url_for(controller: 'manage/instances', action: 'failure', only_path: true)}, []]
    #  @app.call(env)
    #rescue CF::UAA::InvalidToken, CF::UAA::TargetError => e
    #  [200, { "Content-Type" => "text/html" }, [error_html]]
    end
  end

  private

  def error_html
<<-HTML
<html>
<body>
<p>
  This application requires the following permissions:
  <ul>
    <li> Access your profile data including your email address </li>
    <li> View details of your applications and services </li>
  </ul>
  <a href="#{Configuration.manage_user_profile_url}">Manage third-party access</a>
</p>
</body>
</html>
    HTML
  end
end
