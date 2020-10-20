shared class StatsManager
{
	dictionary players;

	StatsManager(GatherMatch@ match)
	{
		Reset();
	}

	Stats@ getStats(string username)
	{
		Stats@ stats;
		if (!players.exists(username))
		{
			Reset(username);
		}
		players.get(username, @stats);
		return stats;
	}

	void Initialize()
	{
		//initialize stats for new players without resetting existing player stats

		GatherMatch@ match = getGatherMatch();
		string[] usernames = match.getPlayers();

		for (uint i = 0; i < usernames.length; i++)
		{
			string username = usernames[i];
			if (!players.exists(username))
			{
				Reset(username);
			}
		}
	}

	void Reset()
	{
		//completely clear and reset stats, now with only participating players

		GatherMatch@ match = getGatherMatch();

		//clear stats
		players.deleteAll();

		//reset stats
		string[] usernames = match.getPlayers();
		for (uint i = 0; i < usernames.length; i++)
		{
			string username = usernames[i];
			Reset(username);
		}
	}

	private void Reset(string username)
	{
		Stats stats(username);
		players.set(username, stats);
	}

	void BlobDie(CRules@ rules, CBlob@ blob)
	{
		CPlayer@ killer = blob.getPlayerOfRecentDamage();
		CPlayer@ victim = blob.getPlayer();

		if (victim !is null)
		{
			getStats(victim.getUsername()).deaths++;

			if (killer !is null && killer.getTeamNum() != blob.getTeamNum())
			{
				getStats(killer.getUsername()).kills++;
			}

		}
	}

	string stringify()
	{
		string str;

		string[]@ usernames = players.getKeys();
		for (uint i = 0; i < usernames.length; i++)
		{
			string username = usernames[i];
			Stats@ stats = getStats(username);

			if (i > 0) str += " ";

			str += stats.stringify();
		}

		return str;
	}
}

shared class Stats
{
	string username;
	uint kills = 0;
	uint deaths = 0;

	Stats(string username)
	{
		this.username = username;
	}

	string stringify()
	{
		return username + " " + kills + " " + deaths;
	}
}
