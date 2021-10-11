#include "GatherMatch.as"
#include "RulesCore.as"
#include "Utilities.as"
#include "WelcomeBanner.as"

string PREFIX = "!";
bool playedStartSound = true;

void onInit(CRules@ this)
{
	this.addCommandID("server_message");
	this.addCommandID("sync_gather_match");
	this.addCommandID("sync_gather_teams");

	if (isClient())
	{
		WelcomeBanner::Init();
	}

	onInitRestart(this);
}

void onRestart(CRules@ this)
{
	onInitRestart(this);

	if (isClient())
	{
		playedStartSound = false;
	}
}

void onInitRestart(CRules@ this)
{
	if (isServer())
	{
		this.set_bool("managed teams", true); //core shouldn't try to manage the teams

		GatherMatch@ gatherMatch = getGatherMatch();
		gatherMatch.restartQueue.Clear();
		gatherMatch.vetoQueue.Clear();
		gatherMatch.tickets.Reset();
		gatherMatch.MovePlayersToTeams();
		gatherMatch.ResetScoreboard();
	}
}

void onTCPRDisconnect(CRules@ this)
{
	getGatherMatch().EndMatch(MatchEndCause::Disconnected);
}

void onTick(CRules@ this)
{
	GatherMatch@ gatherMatch = getGatherMatch();

	if (isClient())
	{
		WelcomeBanner::LoadConfig();

		if (gatherMatch.isLive() && !playedStartSound)
		{
			Sound::Play("party_join.ogg");
			playedStartSound = true;
		}
	}

	if (isServer())
	{
		if (this.get_bool("gather_teams_set"))
		{
			gatherMatch.ReceivedTeams();
			this.set_bool("gather_teams_set", false);
		}

		if (this.get_bool("gather_teams_updated"))
		{
			gatherMatch.UpdatedTeams();
			this.set_bool("gather_teams_updated", false);
		}

		if (this.get_bool("gather_end_match"))
		{
			gatherMatch.EndMatch(MatchEndCause::Forced);
			this.set_bool("gather_end_match", false);
		}

		if (this.get_bool("gather_status"))
		{
			u8 state = this.getCurrentState();
			int blueTickets = gatherMatch.tickets.getBlueTickets();
			int redTickets = gatherMatch.tickets.getRedTickets();
			uint blueAlive = gatherMatch.getAliveCount(0);
			uint redAlive = gatherMatch.getAliveCount(1);

			tcpr("<gather> status " + state + " " + blueTickets + " " + redTickets + " " + blueAlive + " " + redAlive);
			this.set_bool("gather_status", false);
		}

		if (gatherMatch.isPreMatch() && this.isWarmup() && getGameTime() > 0)
		{
			this.SetCurrentState(GAME);
		}

		//sync gather match to clients if not localhost
		if (!isClient())
		{
			CBitStream bs;
			gatherMatch.Serialize(bs);
			this.SendCommand(this.getCommandID("sync_gather_match"), bs, true);
		}
	}
}

void onRender(CRules@ this)
{
	getGatherMatch().RenderHUD();

	if (WelcomeBanner::isVisible())
	{
		WelcomeBanner::Render();
	}
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	WelcomeBanner::SendChatMessage(player);

	RulesCore@ core;
	this.get("core", @core);
	if (core is null) return;

	string username = player.getUsername();
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.isInProgress())
	{
		gatherMatch.SyncTeams(player);

		u8 team = gatherMatch.getTeamNum(username);
		core.ChangePlayerTeam(player, team);

		if (gatherMatch.isLive() && gatherMatch.isParticipating(username))
		{
			string teamName = this.getTeam(team).getName();
			SendMessage(username + ", a missing player for " + teamName + ", has joined", ConsoleColour::CRAZY);
		}
	}
	else if (player.getTeamNum() != this.getSpectatorTeamNum())
	{
		core.ChangePlayerTeam(player, getSmallestTeam(core.teams));
	}
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newTeam)
{
	string username = player.getUsername();
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.isInProgress())
	{
		SendMessage("You cannot change teams while the match is in progress", ConsoleColour::ERROR, player);
	}
	else
	{
		RulesCore@ core;
		this.get("core", @core);
		if (core is null) return;

		core.ChangePlayerTeam(player, newTeam);
	}
}

void onPlayerLeave(CRules@ this, CPlayer@ player)
{
	string username = player.getUsername();
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.isParticipating(username))
	{
		//announce that participant has left mid match
		if (isServer() && gatherMatch.isLive())
		{
			u8 team = gatherMatch.getTeamNum(username);
			string teamName = this.getTeam(team).getName();
			SendMessage(username + " has left the server while playing for " + teamName, ConsoleColour::CRAZY);
		}

		//play ticket warning sounds
		CBlob@ blob = player.getBlob();
		bool isAlive = blob !is null && !blob.hasTag("dead");
		if (isClient() && gatherMatch.tickets.canDecrementTickets() && isAlive)
		{
			gatherMatch.tickets.PlaySound(player);
		}
	}

	//check before removing to suppress the 'already removed' response
	if (isServer() && gatherMatch.readyQueue.isReady(username))
	{
		gatherMatch.readyQueue.Remove(username);
	}
}

void onPlayerDie(CRules@ this, CPlayer@ victim, CPlayer@ attacker, u8 customData)
{
	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.tickets.canDecrementTickets())
	{
		u8 team = victim.getTeamNum();
		u8 otherTeam = (team + 1) % 2;
		int tickets = gatherMatch.tickets.getTickets(team);
		uint aliveCount = gatherMatch.getAliveCount(team);

		//this hook is called before the blob dies if not killed by a player
		bool teamDead = attacker !is null ? aliveCount == 0 : aliveCount <= 1;

		//play ticket warning sounds
		if (isClient())
		{
			gatherMatch.tickets.PlaySound(victim);
		}

		//end game if no more tickets and team is dead
		if (isServer())
		{
			gatherMatch.tickets.DoTicketTug(otherTeam);

			if (tickets == 0 && teamDead)
			{
				string winTeamName = this.getTeam(otherTeam).getName();

				this.SetTeamWon(otherTeam);
				this.SetCurrentState(GAME_OVER);
				this.SetGlobalMessage("{WINNING_TEAM} wins the game!");
				this.AddGlobalMessageReplacement("WINNING_TEAM", winTeamName);

				gatherMatch.EndMatch(MatchEndCause::Tickets);
			}
		}
	}
}

void onStateChange(CRules@ this, const u8 oldState)
{
	if (!isServer()) return;

	GatherMatch@ gatherMatch = getGatherMatch();

	if (gatherMatch.isLive())
	{
		if (this.isMatchRunning())
		{
			this.set_u32("start_time", getGameTime());

			if (gatherMatch.vetoQueue.hasVotes())
			{
				gatherMatch.vetoQueue.Clear();
				SendMessage("All map vetoes have been removed due to build time ending", ConsoleColour::CRAZY);
			}

			if (gatherMatch.restartQueue.hasVotes())
			{
				gatherMatch.restartQueue.Clear();
				SendMessage("All votes to restart have been removed due to build time ending", ConsoleColour::CRAZY);
			}
		}
		else if (this.isGameOver())
		{
			gatherMatch.EndMatch(MatchEndCause::CapturedFlags);
		}
	}
}

bool onClientProcessChat(CRules@ this, const string &in text_in, string &out text_out, CPlayer@ player)
{
	//check if message starts with prefix
	if (text_in.substr(0, PREFIX.length) != PREFIX)
	{
		return true;
	}

	string[] args = text_in.substr(PREFIX.length).split(" ");
	string command = args[0].toLower();
	args.removeAt(0);

	GatherMatch@ gatherMatch = getGatherMatch();

	if (command == "commands")
	{
		if (player.isMyPlayer())
		{
			string[] commands = {
				"help", "Shows the welcome banner",
				"ready/r", "Adds yourself to the ready list",
				"unready/ur", "Removes yourself from the ready list",
				"whoready/wr", "Lists the players who are ready",
				"whonotready/wnr", "Lists the players who are not ready",
				"whomissing/wm", "Lists the players who are not on the server",
				"restart", "Adds your vote to restart the match",
				"veto", "Adds your vote to change the map",
				"scramble", "Adds your vote to scramble teams",
				"tickets", "States the tickets of each team"
			};

			string[] adminCommands = {
				"allspec", "Moves everyone to spectator",
				"forcestart/start", "Starts the match",
				"forceend/end", "Ends the match",
				"clearrestart", "Clears votes to restart the match",
				"forcerestart", "Restarts the match",
				"fullrestart", "Fully restarts the match back to readying phase",
				"clearveto", "Clears votes to change the map",
				"forceveto", "Changes the map",
				"clearscramble", "Clears votes to scramble teams",
				"forcescramble", "Scrambles the teams",
				"clearvotes", "Clears all votes",
				"setbluetickets [tickets]", "Sets the number of tickets on Blue Team",
				"setredtickets [tickets]", "Sets the number of tickets on Red Team",
				"settickets [tickets]", "Sets the number of tickets on both teams",
				"addtickets [tickets]", "Adds tickets to both teams",
				"remtickets [tickets]", "Removes tickets from both teams"
			};

			SendMessage("Commands:", ConsoleColour::CRAZY, player);
			for (uint i = 0; i < commands.length; i += 2)
			{
				string command = commands[i];
				string description = commands[i + 1];
				client_AddToChat(PREFIX + command + " - " + description, ConsoleColour::INFO);
			}

			SendMessage("Admin Commands:", ConsoleColour::CRAZY, player);
			for (uint i = 0; i < adminCommands.length; i += 2)
			{
				string command = adminCommands[i];
				string description = adminCommands[i + 1];
				client_AddToChat(PREFIX + command + " - " + description, ConsoleColour::INFO);
			}
		}
	}
	else if (command == "dismiss")
	{
		if (player.isMyPlayer())
		{
			WelcomeBanner::Dismiss();
		}
	}
	else if (command == "help")
	{
		if (player.isMyPlayer())
		{
			WelcomeBanner::Show();
		}
	}
	else if (!gatherMatch.isInProgress())
	{
		return true;
		//gather-specific commands go after here
	}
	else if (command == "wr" || command == "whoready")
	{
		if (player.isMyPlayer())
		{
			if (gatherMatch.isLive())
			{
				client_AddToChat("The match is already in progress", ConsoleColour::ERROR);
			}
			else
			{
				string[] ready = gatherMatch.readyQueue.getReadyPlayers();
				if (ready.length > 0)
				{
					string text = listUsernames(ready);
					client_AddToChat("Ready: " + text, ConsoleColour::INFO);
				}
				else
				{
					client_AddToChat("No players are ready", ConsoleColour::INFO);
				}
			}
		}
	}
	else if (command == "wnr" || command == "whonotready")
	{
		if (player.isMyPlayer())
		{
			if (gatherMatch.isLive())
			{
				client_AddToChat("The match is already in progress", ConsoleColour::ERROR);
			}
			else
			{
				string[] notReady = gatherMatch.readyQueue.getNotReadyPlayers();
				if (notReady.length > 0)
				{
					string text = listUsernames(notReady);
					client_AddToChat("Not ready: " + text, ConsoleColour::INFO);
				}
				else
				{
					client_AddToChat("All players are ready", ConsoleColour::INFO);
				}
			}
		}
	}
	else if (command == "wm" || command == "whomissing")
	{
		if (player.isMyPlayer())
		{
			string[] missing = gatherMatch.getMissingPlayers();
			if (missing.length > 0)
			{
				string text = listUsernames(missing);
				client_AddToChat("Missing: " + text, ConsoleColour::INFO);
			}
			else
			{
				client_AddToChat("All players are on the server", ConsoleColour::INFO);
			}
		}
	}
	else if (command == "tickets")
	{
		if (player.isMyPlayer())
		{
			int blueTickets = gatherMatch.tickets.getBlueTickets();
			int redTickets = gatherMatch.tickets.getRedTickets();

			string blueText = blueTickets < 0 ? "Infinite" : ("" + blueTickets);
			string redText = redTickets < 0 ? "Infinite" : ("" + redTickets);

			client_AddToChat("Blue tickets: " + blueText, ConsoleColour::INFO);
			client_AddToChat("Red tickets: " + redText, ConsoleColour::INFO);
		}
	}
	else
	{
		//not a gather command
		return true;
	}

	return false;
}

bool onServerProcessChat(CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player)
{
	//check if message starts with prefix
	if (text_in.substr(0, PREFIX.length) != PREFIX)
	{
		return true;
	}

	string[] args = text_in.substr(PREFIX.length).split(" ");
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
				SendMessage(username + " has moved everyone to spectator", ConsoleColour::CRAZY);
			}
			else
			{
				SendMessage("Error moving everyone to spectator", ConsoleColour::ERROR, player);
			}
		}
		else
		{
			SendMessage("Cannot move everyone to spectator while a match is in progress", ConsoleColour::ERROR, player);
		}
	}
	else if (!gatherMatch.isInProgress())
	{
		return true;
		//gather-specific commands go after here
	}
	else if (command == "ready" || command == "r")
	{
		if (!gatherMatch.isParticipating(username))
		{
			SendMessage("You cannot ready because you are not participating in this match", ConsoleColour::ERROR, player);
		}
		else if (gatherMatch.isLive())
		{
			SendMessage("The match is already in progress", ConsoleColour::ERROR, player);
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
			SendMessage("You cannot ready because you are not participating in this match", ConsoleColour::ERROR, player);
		}
		else if (gatherMatch.isLive())
		{
			SendMessage("The match is already in progress", ConsoleColour::ERROR, player);
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
			SendMessage("Only an admin can force start a match", ConsoleColour::ERROR, player);
		}
		else if (gatherMatch.isLive())
		{
			SendMessage("The match is already in progress", ConsoleColour::ERROR, player);
		}
		else
		{
			LoadNextMap();
			SendMessage(username + " has force started the match", ConsoleColour::CRAZY);
			gatherMatch.StartMatch();
		}
	}
	else if (command == "end" || command == "forceend")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can force end a match", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.EndMatch(MatchEndCause::Forced);
		}
	}
	else if (command == "restart")
	{
		if (!gatherMatch.isParticipating(username))
		{
			SendMessage("You cannot vote to restart because you are not participating in this match", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot vote to restart before the match has started", ConsoleColour::ERROR, player);
		}
		else if (this.isMatchRunning())
		{
			SendMessage("You cannot vote to restart after build time has ended", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.restartQueue.Add(username);
		}
	}
	else if (command == "clearrestart")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can clear votes to restart", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.restartQueue.hasVotes())
		{
			SendMessage("There are already no votes to restart", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.restartQueue.Clear();
			SendMessage(username + " has cleared all votes to restart", ConsoleColour::CRAZY);
		}
	}
	else if (command == "forcerestart")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can restart the match", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.restartQueue.Clear();
			gatherMatch.RestartMap();
			SendMessage(username + " has restarted the match", ConsoleColour::CRAZY);
		}
	}
	else if (command == "fullrestart")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can full restart the match", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.ReceivedTeams();
		}
	}
	else if (command == "veto")
	{
		if (!gatherMatch.isParticipating(username))
		{
			SendMessage("You cannot veto the map because you are not participating in this match", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot veto the map before the match has started", ConsoleColour::ERROR, player);
		}
		else if (this.isMatchRunning())
		{
			SendMessage("You cannot veto the map after build time has ended", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.vetoQueue.Add(username);
		}
	}
	else if (command == "clearveto")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can clear map vetoes", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.vetoQueue.hasVotes())
		{
			SendMessage("There are already no map vetoes", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.vetoQueue.Clear();
			SendMessage(username + " has cleared all map vetoes", ConsoleColour::CRAZY);
		}
	}
	else if (command == "forceveto")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can change the map", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.vetoQueue.Clear();
			LoadNextMap();
			SendMessage(username + " has changed the map", ConsoleColour::CRAZY);
		}
	}
	else if (command == "scramble")
	{
		if (!gatherMatch.isParticipating(username))
		{
			SendMessage("You cannot vote to scramble teams because you are not participating in this match", ConsoleColour::ERROR, player);
		}
		else if (gatherMatch.isLive())
		{
			SendMessage("You cannot vote to scramble teams after the match has started", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.scrambleQueue.Add(username);
		}
	}
	else if (command == "clearscramble")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can clear votes to scramble teams", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.scrambleQueue.hasVotes())
		{
			SendMessage("There are already no votes to scramble teams", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.scrambleQueue.Clear();
			SendMessage(username + " has cleared all votes to scramble teams", ConsoleColour::CRAZY);
		}
	}
	else if (command == "forcescramble")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can scramble teams", ConsoleColour::ERROR, player);
		}
		else if (gatherMatch.isLive())
		{
			SendMessage("You cannot scramble teams after the match has started", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.scrambleQueue.Clear();
			gatherMatch.ScrambleTeams();
			SendMessage(username + " has scrambled the teams", ConsoleColour::CRAZY);
		}
	}
	else if (command == "setbluetickets")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can set the tickets", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot set tickets before the match has started", ConsoleColour::ERROR, player);
		}
		else if (args.length < 1)
		{
			SendMessage("Specify a valid number of tickets", ConsoleColour::ERROR, player);
		}
		else
		{
			int tickets = parseInt(args[0]);
			gatherMatch.tickets.SetBlueTickets(tickets);
			tickets = gatherMatch.tickets.getBlueTickets();

			string text = tickets < 0 ? "infinite" : ("" + tickets);
			SendMessage("Blue Team now has " + text + " " + plural(tickets, "ticket"), ConsoleColour::CRAZY);
		}
	}
	else if (command == "setredtickets")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can set the tickets", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot set tickets before the match has started", ConsoleColour::ERROR, player);
		}
		else if (args.length < 1)
		{
			SendMessage("Specify a valid number of tickets", ConsoleColour::ERROR, player);
		}
		else
		{
			int tickets = parseInt(args[0]);
			gatherMatch.tickets.SetRedTickets(tickets);
			tickets = gatherMatch.tickets.getRedTickets();

			string text = tickets < 0 ? "infinite" : ("" + tickets);
			SendMessage("Red Team now has " + text + " " + plural(tickets, "ticket"), ConsoleColour::CRAZY);
		}
	}
	else if (command == "settickets")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can set the tickets", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot set the tickets before the match has started", ConsoleColour::ERROR, player);
		}
		else if (args.length < 1)
		{
			SendMessage("Specify a valid number of tickets", ConsoleColour::ERROR, player);
		}
		else
		{
			string arg = args[0].toLower();
			int tickets = arg == "infinite" || arg == "unlimited" ? -1 : parseInt(args[0]);

			gatherMatch.tickets.SetBlueTickets(tickets);
			gatherMatch.tickets.SetRedTickets(tickets);

			tickets = gatherMatch.tickets.getBlueTickets();

			string text = tickets < 0 ? "infinite" : ("" + tickets);
			SendMessage("Both teams now have " + text + " " + plural(tickets, "ticket"), ConsoleColour::CRAZY);
		}
	}
	else if (command == "addtickets")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can add tickets", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot add tickets before the match has started", ConsoleColour::ERROR, player);
		}
		else if (args.length < 1)
		{
			SendMessage("Specify a valid number of tickets to add", ConsoleColour::ERROR, player);
		}
		else
		{
			int tickets = parseInt(args[0]);

			int blueTickets = gatherMatch.tickets.getBlueTickets();
			int redTickets = gatherMatch.tickets.getRedTickets();

			if (blueTickets > -1)
			{
				gatherMatch.tickets.SetBlueTickets(blueTickets + tickets);
			}

			if (redTickets > -1)
			{
				gatherMatch.tickets.SetRedTickets(redTickets + tickets);
			}

			SendMessage("Both teams now have " + tickets + " more " + plural(tickets, "ticket"), ConsoleColour::CRAZY);
		}
	}
	else if (command == "removetickets" || command == "remtickets" || command == "subtickets")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can remove tickets", ConsoleColour::ERROR, player);
		}
		else if (!gatherMatch.isLive())
		{
			SendMessage("You cannot remove tickets before the match has started", ConsoleColour::ERROR, player);
		}
		else if (args.length < 1)
		{
			SendMessage("Specify a valid number of tickets to remove", ConsoleColour::ERROR, player);
		}
		else
		{
			int tickets = parseInt(args[0]);

			int blueTickets = gatherMatch.tickets.getBlueTickets();
			int redTickets = gatherMatch.tickets.getRedTickets();

			if (blueTickets > 0)
			{
				blueTickets = Maths::Max(0, blueTickets - tickets);
			}

			if (redTickets > 0)
			{
				redTickets = Maths::Max(0, redTickets - tickets);
			}

			gatherMatch.tickets.SetBlueTickets(blueTickets);
			gatherMatch.tickets.SetRedTickets(redTickets);

			SendMessage("Both teams now have " + tickets + " fewer " + plural(tickets, "ticket"), ConsoleColour::CRAZY);
		}
	}
	else if (command == "clearvotes")
	{
		if (!player.isMod())
		{
			SendMessage("Only an admin can clear votes", ConsoleColour::ERROR, player);
		}
		else
		{
			gatherMatch.restartQueue.Clear();
			gatherMatch.vetoQueue.Clear();
			gatherMatch.scrambleQueue.Clear();
			SendMessage(username + " has cleared all votes", ConsoleColour::CRAZY);
		}
	}
	else
	{
		//not a gather command
		return true;
	}

	return false;
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("server_message"))
	{
		if (isClient())
		{
			string message;
			if (!params.saferead_string(message)) return;

			uint color;
			if (!params.saferead_u32(color)) return;

			client_AddToChat(message, color);
		}
	}
	else if (cmd == this.getCommandID("sync_gather_match"))
	{
		if (isClient())
		{
			GatherMatch gatherMatch;
			if (!gatherMatch.deserialize(params)) return;

			this.set("gather_match", gatherMatch);
		}
	}
	else if (cmd == this.getCommandID("sync_gather_teams"))
	{
		if (isClient())
		{
			getGatherMatch().deserializeTeams(params);
		}
	}
}
