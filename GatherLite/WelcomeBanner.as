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
}
