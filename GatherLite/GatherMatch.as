#include "ReadyQueue.as"
#include "RestartQueue.as"
#include "VetoQueue.as"
#include "ScrambleQueue.as"
#include "Tickets.as"

shared GatherMatch@ getGatherMatch()
{
	CRules@ rules = getRules();

	GatherMatch@ gatherMatch;
	if (rules.get("gather_match", @gatherMatch))
	{
		return gatherMatch;
	}

	@gatherMatch = GatherMatch();
	rules.set("gather_match", gatherMatch);
	return gatherMatch;
}

shared class GatherMatch
{
	ReadyQueue@ readyQueue = ReadyQueue();
	RestartQueue@ restartQueue = RestartQueue();
	VetoQueue@ vetoQueue = VetoQueue();
	ScrambleQueue@ scrambleQueue = ScrambleQueue();
	Tickets@ tickets = Tickets();

	private bool matchIsLive = false;

	GatherMatch()
	{
		LoadConfig();
	}

	GatherMatch(CBitStream@ bs)
	{
		readyQueue = ReadyQueue(bs);
		restartQueue = RestartQueue(bs);
		vetoQueue = VetoQueue(bs);
		scrambleQueue = ScrambleQueue(bs);
		tickets = Tickets(bs);

		matchIsLive = bs.read_bool();
	}

	void ReceivedTeams()
	{
		readyQueue.Clear();
		scrambleQueue.Clear();

		if (isServer())
		{
			LoadNextMap();
		}
	}

	void StartMatch()
	{
		matchIsLive = true;
		readyQueue.Clear();

		if (isServer())
		{
			LoadNextMap();
			tcpr("<gather> started");
		}

		if (isClient())
		{
			client_AddToChat("Match begun!", SColor(255, 255, 0, 0));
		}
	}

	void EndMatch()
	{
		matchIsLive = false;

		CRules@ rules = getRules();
		rules.clear("blue_team");
		rules.clear("red_team");

		if (isServer())
		{
			u8 winningTeam = getRules().getTeamWon();
			tcpr("<gather> ended " + winningTeam);
		}

		if (isClient())
		{
			client_AddToChat("Match ended!", SColor(255, 255, 0, 0));
		}
	}

	bool isInProgress()
	{
		return getPlayerCount() > 0;
	}

	bool isLive()
	{
		return matchIsLive;
	}

	bool isParticipating(string username)
	{
		return getTeamNum(username) != getRules().getSpectatorTeamNum();
	}

	u8 getTeamNum(string username)
	{
		int blueIndex = getBlueTeam().find(username);
		if (blueIndex > -1)
		{
			return 0;
		}

		int redIndex = getRedTeam().find(username);
		if (redIndex > -1)
		{
			return 1;
		}

		return getRules().getSpectatorTeamNum();
	}

	string[] getBlueTeam()
	{
		string[] players;
		getRules().get("blue_team", players);
		return players;
	}

	string[] getRedTeam()
	{
		string[] players;
		getRules().get("red_team", players);
		return players;
	}

	string[] getPlayers(u8 team)
	{
		string[] players;
		switch (team)
		{
			case 0:
				players = getBlueTeam();
				break;
			case 1:
				players = getRedTeam();
				break;
		}
		return players;
	}

	string[] getPlayers()
	{
		string[] arr = getBlueTeam();

		string[] redTeam = getRedTeam();
		for (uint i = 0; i < redTeam.length; i++)
		{
			string username = redTeam[i];
			arr.push_back(username);
		}

		return arr;
	}

	bool allPlayersDead(u8 team)
	{
		string[] players = getPlayers(team);

		for (uint i = 0; i < players.length; i++)
		{
			string username = players[i];
			CPlayer@ player = getPlayerByUsername(username);
			CBlob@ blob = player.getBlob();

			if (blob !is null && !blob.hasTag("dead"))
			{
				return false;
			}
		}

		return true;
	}

	uint getPlayerCount()
	{
		return getBlueTeam().length + getRedTeam().length;
	}

	bool canSpawn(CPlayer@ player)
	{
		if (isLive())
		{
			u8 team = player.getTeamNum();
			return tickets.hasTickets(team);
		}
		return true;
	}

	void RenderHUD()
	{
		if (isLive())
		{
			CRules@ rules = getRules();

			uint blueTickets = tickets.getBlueTickets();
			uint redTickets = tickets.getRedTickets();

			SColor blueColor = rules.getTeam(0).color;
			SColor redColor = rules.getTeam(1).color;

			Vec2f pos(440, getScreenHeight() - 100);

			GUI::DrawTextCentered("Spawns Remaining:", pos, color_white);
			GUI::DrawTextCentered("" + blueTickets, pos + Vec2f(-30, 20), blueColor);
			GUI::DrawTextCentered("" + redTickets, pos + Vec2f(30, 20), redColor);
		}
	}

	void LoadConfig()
	{
		ConfigFile@ cfg = ConfigFile();
		if (cfg.loadFile("gather.cfg"))
		{
			tickets.LoadConfig(cfg);
		}
		else
		{
			warn("Gather config file not found");
		}
	}

	void Serialize(CBitStream@ bs)
	{
		readyQueue.Serialize(bs);
		restartQueue.Serialize(bs);
		vetoQueue.Serialize(bs);
		scrambleQueue.Serialize(bs);
		tickets.Serialize(bs);

		bs.write_bool(matchIsLive);
	}
}
