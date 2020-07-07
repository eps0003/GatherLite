namespace WelcomeBanner
{
	void Init()
	{
		GUI::LoadFont("heading", "GUI/Fonts/AveriaSerif-Bold.ttf", 40, true);
		GUI::LoadFont("body", "GUI/Fonts/AveriaSerif-Regular.ttf", 16, true);
	}

	void LoadConfig()
	{
		CRules@ rules = getRules();

		if (!rules.exists("new_to_gather"))
		{
			ConfigFile cfg = ConfigFile();
			if (!cfg.loadFile("../Cache/Gather.cfg"))
			{
				cfg.add_bool("new_to_gather", true);
				cfg.saveFile("Gather.cfg");
			}

			bool new = cfg.read_bool("new_to_gather", true);
			rules.set_bool("new_to_gather", new);
		}
	}

	bool isVisible()
	{
		return getRules().get_bool("new_to_gather");
	}

	void Show()
	{
		getRules().set_bool("new_to_gather", true);
	}

	void Dismiss()
	{
		ConfigFile cfg = ConfigFile();
		if (cfg.loadFile("../Cache/Gather.cfg"))
		{
			cfg.add_bool("new_to_gather", false);
			cfg.saveFile("Gather.cfg");
		}

		getRules().set_bool("new_to_gather", false);
	}

	void SendChatMessage(CPlayer@ player)
	{
		SendMessage("=================== Welcome to Gather! ====================", ConsoleColour::CRAZY, player);
		SendMessage("Gather is a CTF event involving the use of a Discord bot to organise matches. Join the Discord in the server description to participate, and type " + PREFIX + "commands for a list of commands!", ConsoleColour::CRAZY, player);
		SendMessage("====================================================", ConsoleColour::CRAZY, player);
	}

	void Render()
	{
		uint screenWidth = getScreenWidth();
		uint screenHeight = getScreenHeight();

		string heading = "Welcome to Gather!";
		GUI::SetFont("heading");

		Vec2f headingDim;
		GUI::GetTextDimensions(heading, headingDim);

		uint windowWidth = headingDim.x + 240;
		uint windowHeight = 350;

		Vec2f tl = Vec2f(screenWidth - windowWidth, screenHeight - windowHeight) / 2.0f;
		Vec2f br = Vec2f(screenWidth + windowWidth, screenHeight + windowHeight) / 2.0f;

		GUI::DrawWindow(tl, br);

		GUI::DrawTextCentered(heading, Vec2f(screenWidth / 2.0f, tl.y + 50), ConsoleColour::INFO);
		GUI::DrawIcon("GatherFlagFlipped.png", 0, Vec2f(-32, 32), Vec2f(screenWidth / 2.0f - headingDim.x / 2.0f, tl.y), 1.5f, 0);
		GUI::DrawIcon("GatherFlag.png", 0, Vec2f(32, 32), Vec2f(screenWidth / 2.0f + headingDim.x / 2.0f, tl.y), 1.5f, 1);

		GUI::SetFont("body");

		uint padding = 20;

		GUI::DrawText("Gather is a CTF event involving the use of a Discord bot to organise matches\n\nTo participate in a match, please do the following:\n   1.   Join the Discord in the server description\n   2.   !add to the queue in #gather-general\n   3.   Join this server when the queue is filled and teams have been assigned\n   4.   Type " + PREFIX + "ready in chat to add yourself to the ready list\n   5.   Wait for everyone to ready\n   6.   Play!\n\nType " + PREFIX + "commands in chat for a full list of commands\nType " + PREFIX + "dismiss in chat to dismiss this window", tl + Vec2f(padding, 100), br - Vec2f(padding, padding), ConsoleColour::INFO, false, false);
	}
}
