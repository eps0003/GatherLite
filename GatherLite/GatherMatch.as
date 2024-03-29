#include "Utilities.as"
#include "ReadyQueue.as"
#include "RestartQueue.as"
#include "VetoQueue.as"
#include "ScrambleQueue.as"
#include "Tickets.as"
#include "StatsManager.as"

shared enum MatchEndCause
{
	Disconnected,
	Forced,
	CapturedFlags,
	Tickets
}

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
	StatsManager@ stats = StatsManager();

	private bool matchIsLive = false;

	GatherMatch()
	{
		LoadConfig();
	}

	void UpdatedTeams()
	{
		MovePlayersToTeams();
		CleanQueues();
		SyncTeams();

		//initialize stats for new players
		stats.Initialize();

		//the final non-ready player might have been removed
		if (readyQueue.isEveryoneReady())
		{
			LoadNextMap();
			StartMatch();
		}
	}

	void ReceivedTeams()
	{
		matchIsLive = false;

		readyQueue.Clear();
		scrambleQueue.Clear();

		//completely reset stats since we have new teams
		stats.Reset();

		LoadNextMap();
		SyncTeams();

		CRules@ rules = getRules();

		string blueTeam = listUsernames(getBlueTeam());
		string redTeam = listUsernames(getRedTeam());
		SColor blueColor = rules.getTeam(0).color;
		SColor redColor = rules.getTeam(1).color;

		SendMessage("================= A match is about to begin! ==================", ConsoleColour::CRAZY);
		SendMessage("Blue Team: " + blueTeam, blueColor);
		SendMessage("Red Team: " + redTeam, redColor);
		SendMessage("All players need to !ready in order for the game to begin", ConsoleColour::INFO);
		SendMessage("====================================================", ConsoleColour::CRAZY);
	}

	void StartMatch()
	{
		matchIsLive = true;

		readyQueue.Clear();
		scrambleQueue.Clear();

		tcpr("<gather> started");
		SendMessage("===================== Match begun! ======================", ConsoleColour::CRAZY);
	}

	void EndMatch(MatchEndCause cause)
	{
		if (isInProgress())
		{
			CRules@ rules = getRules();

			s8 winningTeam = rules.getTeamWon();
			uint duration = (isLive() && !rules.isWarmup()) ? (getGameTime() - rules.get_u32("start_time")) : 0;
			int blueTickets = tickets.getBlueTickets();
			int redTickets = tickets.getRedTickets();
			string[] mapPath = getMap().getMapName().split("/");
			string map = mapPath[mapPath.length - 1];
			map = map.substr(0, map.length - 4);

			matchIsLive = false;

			tcpr("<gather> ended " + cause + " " + winningTeam + " " + duration + " " + map + " " + blueTickets + " " + redTickets + " " + stats.stringify());
			SendMessage("===================== Match ended! ======================", ConsoleColour::CRAZY);

			rules.clear("blue_team");
			rules.clear("red_team");
			SyncTeams();
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

	bool isPreMatch()
	{
		return isInProgress() && !isLive();
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

	uint getTeamSize(u8 team)
	{
		return getPlayers(team).length;
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

	string[] getMissingPlayers()
	{
		string[] players = getPlayers();
		string[] missing;

		for (uint i = 0; i < players.length; i++)
		{
			string username = players[i];
			CPlayer@ player = getPlayerByUsername(username);

			if (player is null)
			{
				missing.push_back(username);
			}
		}

		return missing;
	}

	bool allPlayersDead(u8 team)
	{
		string[] players = getPlayers(team);

		for (uint i = 0; i < players.length; i++)
		{
			string username = players[i];
			CPlayer@ player = getPlayerByUsername(username);
			if (player !is null)
			{
				CBlob@ blob = player.getBlob();
				if (blob !is null && !blob.hasTag("dead"))
				{
					return false;
				}
			}
		}

		return true;
	}

	uint getDeadCount(u8 team)
	{
		//this doesnt include teammates not in game

		string[] players = getPlayers(team);
		uint dead = 0;

		for (uint i = 0; i < players.length; i++)
		{
			string username = players[i];
			CPlayer@ player = getPlayerByUsername(username);
			if (player !is null)
			{
				CBlob@ blob = player.getBlob();
				if (blob is null || blob.hasTag("dead"))
				{
					dead++;
				}
			}
		}

		return dead;
	}

	uint getAliveCount(u8 team)
	{
		string[] players = getPlayers(team);
		uint alive = 0;

		for (uint i = 0; i < players.length; i++)
		{
			string username = players[i];
			CPlayer@ player = getPlayerByUsername(username);
			if (player !is null)
			{
				CBlob@ blob = player.getBlob();
				if (blob !is null && !blob.hasTag("dead"))
				{
					alive++;
				}
			}
		}

		return alive;
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
		if (g_videorecording) return;

		if (isLive())
		{
			tickets.RenderHUD();
		}
		else if (isInProgress())
		{
			readyQueue.RenderHUD();
		}
	}

	void MovePlayersToTeams()
	{
		if (isInProgress())
		{
			RulesCore@ core;
			getRules().get("core", @core);
			if (core is null) return;

			for (uint i = 0; i < getPlayersCount(); i++)
			{
				CPlayer@ player = getPlayer(i);
				if (player !is null)
				{
					string username = player.getUsername();
					u8 team = getTeamNum(username);

					if (player.getTeamNum() != team)
					{
						core.ChangePlayerTeam(player, team);
					}
				}
			}
		}
	}

	void RestartMap()
	{
		LoadMap(getMap().getMapName());
	}

	void ScrambleTeams()
	{
		tcpr("<gather> scramble");
	}

	void ResetScoreboard()
	{
		//clear scoreboard
		for (uint i = 0; i < getPlayersCount(); i++)
		{
			CPlayer@ player = getPlayer(i);
			if (player !is null)
			{
				player.setKills(0);
				player.setDeaths(0);
				player.setAssists(0);
			}
		}
	}

	void CheckWin(u8 team)
	{
		if (tickets.canDecrementTickets())
		{
			//end game if no more tickets and team is dead
			if (!tickets.hasTickets(team) && allPlayersDead(team))
			{
				CRules@ rules = getRules();

				u8 winTeam = (team + 1) % 2;
				string winTeamName = rules.getTeam(winTeam).getName();

				rules.SetTeamWon(winTeam);
				rules.SetCurrentState(GAME_OVER);
				rules.SetGlobalMessage("{WINNING_TEAM} wins the game!");
				rules.AddGlobalMessageReplacement("WINNING_TEAM", winTeamName);

				EndMatch(MatchEndCause::Tickets);
			}
		}
	}

	void LoadConfig()
	{
		ConfigFile@ cfg = ConfigFile();
		if (cfg.loadFile("gather.cfg"))
		{
			restartQueue.LoadConfig(cfg);
			vetoQueue.LoadConfig(cfg);
			scrambleQueue.LoadConfig(cfg);
			tickets.LoadConfig(cfg);
		}
		else
		{
			warn("Gather config file not found");
		}
	}

	void Serialize(CBitStream@ bs)
	{
		bs.write_bool(matchIsLive);

		if (isInProgress())
		{
			if (matchIsLive)
			{
				// restartQueue.Serialize(bs);
				// vetoQueue.Serialize(bs);
				// scrambleQueue.Serialize(bs);
				tickets.Serialize(bs);
			}
			else
			{
				readyQueue.Serialize(bs);
			}
		}
	}

	bool deserialize(CBitStream@ bs)
	{
		if (!bs.saferead_bool(matchIsLive)) return false;

		if (isInProgress())
		{
			if (matchIsLive)
			{
				// if (!restartQueue.deserialize(bs)) return false;
				// if (!vetoQueue.deserialize(bs)) return false;
				// if (!scrambleQueue.deserialize(bs)) return false;
				if (!tickets.deserialize(bs)) return false;
			}
			else
			{
				if (!readyQueue.deserialize(bs)) return false;
			}
		}

		return true;
	}

	bool deserializeTeams(CBitStream@ bs)
	{
		uint blueCount;
		if (!bs.saferead_u32(blueCount)) return false;

		string[] blueTeam;
		for (uint i = 0; i < blueCount; i++)
		{
			string username;
			if (!bs.saferead_string(username)) return false;

			blueTeam.push_back(username);
		}

		uint redCount;
		if (!bs.saferead_u32(redCount)) return false;

		string[] redTeam;
		for (uint i = 0; i < redCount; i++)
		{
			string username;
			if (!bs.saferead_string(username)) return false;

			redTeam.push_back(username);
		}

		CRules@ rules = getRules();
		rules.set("blue_team", blueTeam);
		rules.set("red_team", redTeam);

		return true;
	}

	void SyncTeams()
	{
		CBitStream bs;
		SerializeTeams(bs);

		CRules@ rules = getRules();
		rules.SendCommand(rules.getCommandID("sync_gather_teams"), bs, true);
	}

	void SyncTeams(CPlayer@ player)
	{
		CBitStream bs;
		SerializeTeams(bs);

		CRules@ rules = getRules();
		rules.SendCommand(rules.getCommandID("sync_gather_teams"), bs, player);
	}

	private void SerializeTeams(CBitStream@ bs)
	{
		string[] blueTeam = getBlueTeam();
		bs.write_u32(blueTeam.length);
		for (uint i = 0; i < blueTeam.length; i++)
		{
			string username = blueTeam[i];
			bs.write_string(username);
		}

		string[] redTeam = getRedTeam();
		bs.write_u32(redTeam.length);
		for (uint i = 0; i < redTeam.length; i++)
		{
			string username = redTeam[i];
			bs.write_string(username);
		}
	}

	private void CleanQueues()
	{
		readyQueue.Clean();
		restartQueue.Clean();
		vetoQueue.Clean();
		scrambleQueue.Clean();
	}
}
