class CatchOauthErrors
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      @app.call(env)
    rescue CF::UAA::InvalidToken, CF::UAA::TargetError => e
      [200, { "Content-Type" => "text/html" }, [error_html]]
    end
  end

  private

  def error_html
<<-HTML
<html>
<p>
  This application requires the following permissions:
  <ul>
    <li> View details of your applications and services </li>
    <li> Access your profile data including your email address </li>
  </ul>
  <a href="#{Configuration.manage_user_profile_url}">Manage third-party access</a>
</p>
</html>
    HTML
  end
end