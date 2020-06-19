#include "GatherMatch.as"
#include "RulesCore.as"

SColor color(255, 255, 0, 0);

void onInit(CRules@ this)
{
	onRestart(this);
}

void onRestart(CRules@ this)
{
	this.set_bool("managed teams", true); //core shouldn't try to manage the teams

	GatherMatch@ gatherMatch = getGatherMatch();
	gatherMatch.restartQueue.Clear();
	gatherMatch.vetoQueue.Clear();
	gatherMatch.tickets.Reset();

	if (gatherMatch.isInProgress() && isServer())
	{
		RulesCore@ core;
		this.get("core", @core);
		if (core is null) return;

		for (uint i = 0; i < getPlayersCount(); i++)
		{
			CPlayer@ player = getPlayer(i);
			string username = player.getUsername();
			u8 team = gatherMatch.getTeamNum(username);
			core.ChangePlayerTeam(player, team);
		}
	}
}

void onTCPRDisconnect(CRules@ this)
{
	getGatherMatch().EndMatch();
}

void onTick(CRules@ this)
{
	GatherMatch@ gatherMatch = getGatherMatch();

	if (this.get_bool("gather_teams_set"))
	{
		gatherMatch.ReceivedTeams();
		this.set_bool("gather_teams_set", false);
	}

	if (this.get_bool("gather_end_match"))
	{
		gatherMatch.EndMatch();
		this.set_bool("gather_end_match", false);
	}

	if (this.get_bool("gather_status"))
	{
		uint blueTickets = gatherMatch.tickets.getBlueTickets();
		uint redTickets = gatherMatch.tickets.getRedTickets();

		tcpr("<gather> status " + blueTickets + " " + redTickets);
		this.set_bool("gather_status", false);
	}
}

void onRender(CRules@ this)
{
	getGatherMatch().RenderHUD();
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	if (isServer())
	{
		RulesCore@ core;
		this.get("core", @core);
		if (core is null) return;

		string username = player.getUsername();
		GatherMatch@ gatherMatch = getGatherMatch();

		if (gatherMatch.isInProgress())
		{
			u8 team = gatherMatch.getTeamNum(username);
			core.ChangePlayerTeam(player, team);
		}
		else if (player.getTeamNum() != this.getSpectatorTeamNum())
		{
			core.ChangePlayerTeam(player, getSmallestTeam(core.teams));
		}
	}

	if (player.isMyPlayer())
	{
		client_AddToChat("=================== Welcome to Gather! ====================", color);
		client_AddToChat("Gather is a organised CTF event involving the use of an automated Discord bot to organise matches. Join the Discord in the server description to participate!", color);
		client_AddToChat("====================================================", color);
	}
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newTeam)
{
	string username = player.getUsername();
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.isInProgress())
	{
		if (player.isMyPlayer())
		{
			client_AddToChat("You cannot change teams while the match is in progress", color);
		}
	}
	else
	{
		if (isServer())
		{
			RulesCore@ core;
			this.get("core", @core);
			if (core is null) return;

			core.ChangePlayerTeam(player, newTeam);
		}
	}
}

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
	string username = player.getUsername();
	GatherMatch@ gatherMatch = getGatherMatch();

	gatherMatch.readyQueue.Remove(username);
	gatherMatch.restartQueue.Remove(username);
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ killer, u8 customData)
{
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.tickets.canDecrementTickets())
	{
		u8 team = victim.getTeamNum();
		uint tickets = gatherMatch.tickets.getTickets(team);

		if (tickets <= 0)
		{
			Sound::Play("depleted.ogg");

			if (!gatherMatch.allPlayersDead(team))
			{
				u8 winTeam = (team + 1) % 2;
				string winTeamName = this.getTeam(winTeam).getName();

				this.SetTeamWon(winTeam);
				this.SetCurrentState(GAME_OVER);
				this.SetGlobalMessage("{WINNING_TEAM} wins the game!");
				this.AddGlobalMessageReplacement("WINNING_TEAM", winTeamName);
			}
		}
		else if (tickets <= 5)
		{
			Sound::Play("depleting.ogg");
		}
	}
}

void onStateChange(CRules@ this, const u8 oldState)
{
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.isLive() && this.isGameOver())
	{
		gatherMatch.EndMatch();
	}
}

bool onServerProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	string prefix = "!";
	string[] args = text_in.substr(prefix.length).split(" ");
	string command = args[0].toLower();
	args.removeAt(0);

	string username = player.getUsername();
	GatherMatch@ gatherMatch = getGatherMatch();

	if (command == "allspec")
	{
		if (!gatherMatch.isInProgress())
		{
			RulesCore@ core;
			this.get("core", @core);
			if (core !is null)
			{
				for (uint i = 0; i < getPlayersCount(); i++)
				{
					CPlayer@ player = getPlayer(i);
					core.ChangePlayerTeam(player, this.getSpectatorTeamNum());
				}
				getNet().server_SendMsg("Everyone has been moved to spectator");
			}
			else
			{
				getNet().server_SendMsg("Error moving everyone to spectator");
			}
		}
		else
		{
			getNet().server_SendMsg("Cannot move everyone to spectator while a match is in progress");
		}
	}
	else if (!gatherMatch.isInProgress())
	{
		//gather-specific commands go after here
	}
	else if (command == "ready" || command == "r")
	{
		if (!gatherMatch.isParticipating(username))
		{
			getNet().server_SendMsg("You cannot ready if you are not participating in this match, " + username);
		}
		else if (player.getTeamNum() == this.getSpectatorTeamNum())
		{
			getNet().server_SendMsg("You must be in a team to ready, " + username);
		}
		else if (gatherMatch.isLive())
		{
			getNet().server_SendMsg("The match is already in progress, " + username);
		}
		else if (gatherMatch.readyQueue.isReady(username))
		{
			getNet().server_SendMsg("You are already ready, " + username);
		}
		else
		{
			gatherMatch.readyQueue.Add(username);
		}
	}
	else if (command == "unready" || command == "ur")
	{
		if (!gatherMatch.isParticipating(username))
		{
			getNet().server_SendMsg("You cannot unready if you are not participating in this match, " + username);
		}
		else if (gatherMatch.isLive())
		{
			getNet().server_SendMsg("You cannot unready while the match is in progress, " + username);
		}
		else if (!gatherMatch.readyQueue.isReady(username))
		{
			getNet().server_SendMsg("You are already not ready, " + username);
		}
		else
		{
			gatherMatch.readyQueue.Remove(username);
		}
	}
	else if (command == "start" || command == "forcestart")
	{
		if (!player.isMod())
		{
			getNet().server_SendMsg("Only a mod can force start a match, " + username);
		}
		else if (gatherMatch.isLive())
		{
			getNet().server_SendMsg("The match is already in progress, " + username);
		}
		else
		{
			gatherMatch.StartMatch();
		}
	}
	else if (command == "end" || command == "forceend")
	{
		if (!player.isMod())
		{
			getNet().server_SendMsg("Only a mod can force end a match, " + username);
		}
		else
		{
			gatherMatch.EndMatch();
		}
	}
	else if (command == "restart")
	{
		if (!gatherMatch.isParticipating(username))
		{
			getNet().server_SendMsg("You cannot vote to restart if you are not participating in this match, " + username);
		}
		else if (!gatherMatch.isLive())
		{
			getNet().server_SendMsg("You cannot vote to restart before the match has started, " + username);
		}
		else if (gatherMatch.restartQueue.hasVoted(username))
		{
			getNet().server_SendMsg("You already voted to restart, " + username);
		}
		else
		{
			gatherMatch.restartQueue.Add(username);
		}
	}
	else if (command == "wr" || command == "whoready")
	{
		if (gatherMatch.isLive())
		{
			getNet().server_SendMsg("The match is already in progress, " + username);
		}
		else
		{
			string[] ready = gatherMatch.readyQueue.getReadyPlayers();
			if (ready.length > 0)
			{
				string text = listUsernames(ready);
				getNet().server_SendMsg("Ready: " + text);
			}
			else
			{
				getNet().server_SendMsg("Nobody is ready");
			}
		}
	}
	else if (command == "wnr" || command == "whonotready")
	{
		if (gatherMatch.isLive())
		{
			getNet().server_SendMsg("The match is already in progress, " + username);
		}
		else
		{
			string[] notReady = gatherMatch.readyQueue.getNotReadyPlayers();
			if (notReady.length > 0)
			{
				string text = listUsernames(notReady);
				getNet().server_SendMsg("Not ready: " + text);
			}
			else
			{
				getNet().server_SendMsg("Everyone is ready");
			}
		}
	}
	else if (command == "veto")
	{
		if (!gatherMatch.isParticipating(username))
		{
			getNet().server_SendMsg("You cannot veto the map if you are not participating in this match, " + username);
		}
		else if (!gatherMatch.isLive())
		{
			getNet().server_SendMsg("You cannot veto the map before the match has started, " + username);
		}
		else if (gatherMatch.vetoQueue.hasVoted(username))
		{
			getNet().server_SendMsg("You already vetoed the map, " + username);
		}
		else
		{
			gatherMatch.vetoQueue.Add(username);
		}
	}
	else if (command == "rsub" || command == "reqsub" || command == "requestsub")
	{

	}
	else if (command == "scramble" || command == "scrambleteams")
	{
		if (!gatherMatch.isParticipating(username))
		{
			getNet().server_SendMsg("You cannot vote to scramble teams if you are not participating in this match, " + username);
		}
		else if (gatherMatch.isLive())
		{
			getNet().server_SendMsg("You cannot vote to scramble teams after the match has started, " + username);
		}
		else if (gatherMatch.scrambleQueue.hasVoted(username))
		{
			getNet().server_SendMsg("You already voted to scramble teams, " + username);
		}
		else
		{
			gatherMatch.scrambleQueue.Add(username);
		}
	}
	else if (command == "freeze" || command == "pause" || command == "wait")
	{

	}
	else if (command == "unfreeze" || command == "unpause" || command == "resume" || command == "continue")
	{

	}
	else if (command == "tickets")
	{
		uint blueTickets = gatherMatch.tickets.getBlueTickets();
		uint redTickets = gatherMatch.tickets.getRedTickets();
		getNet().server_SendMsg("Blue tickets: " + blueTickets);
		getNet().server_SendMsg("Red tickets: " + redTickets);
	}
	else if (command == "setbluetickets")
	{
		if (!player.isMod())
		{
			getNet().server_SendMsg("Only a mod can set the tickets, " + username);
		}
		else if (args.length < 1)
		{
			getNet().server_SendMsg("Please enter a valid number of tickets, " + username);
		}
		else
		{
			uint tickets = parseInt(args[0]);
			gatherMatch.tickets.SetBlueTickets(tickets);
			getNet().server_SendMsg("Blue Team now has " + tickets + " " + plural(tickets, "ticket"));
		}
	}
	else if (command == "setredtickets")
	{
		if (!player.isMod())
		{
			getNet().server_SendMsg("Only a mod can set the tickets, " + username);
		}
		else if (args.length < 1)
		{
			getNet().server_SendMsg("Please enter a valid number of tickets, " + username);
		}
		else
		{
			uint tickets = parseInt(args[0]);
			gatherMatch.tickets.SetRedTickets(tickets);
			getNet().server_SendMsg("Red Team now has " + tickets + " " + plural(tickets, "ticket"));
		}
	}
	else if (command == "settickets")
	{
		if (!player.isMod())
		{
			getNet().server_SendMsg("Only a mod can set the tickets, " + username);
		}
		else if (args.length < 1)
		{
			getNet().server_SendMsg("Please enter a valid number of tickets, " + username);
		}
		else
		{
			uint tickets = parseInt(args[0]);
			gatherMatch.tickets.SetBlueTickets(tickets);
			gatherMatch.tickets.SetRedTickets(tickets);
		}
	}

	return true;
}

string listUsernames(string[] usernames)
{
	string text;
	for (uint i = 0; i < usernames.length; i++)
	{
		if (i > 0)
		{
			text += ", ";
		}
		text += usernames[i];
	}
	return text;
}

string plural(int value, string word, string suffix = "s")
{
	if (value == 1)
	{
		return word;
	}
	else
	{
		return word + suffix;
	}
}
