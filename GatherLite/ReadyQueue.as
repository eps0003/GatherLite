#include "Queue.as"

shared class ReadyQueue
{
	private Queue queue;

	ReadyQueue(CBitStream@ bs)
	{
		queue = Queue(bs);
	}

	void Add(string username)
	{
		if (queue.Add(username))
		{
			bool everyoneReady = isEveryoneReady();
			uint count = queue.getCount();

			if (everyoneReady)
			{
				LoadNextMap();
			}

			SendMessage(username + " is now ready (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (everyoneReady)
			{
				getGatherMatch().StartMatch();
			}
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You are already ready", ConsoleColour::ERROR, player);
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			SendMessage(username + " is no longer ready (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You are already not ready", ConsoleColour::ERROR, player);
		}
	}

	void Clear()
	{
		queue.Clear();
	}

	string[] getReadyPlayers()
	{
		return queue.getPlayers();
	}

	string[] getNotReadyPlayers()
	{
		string[] matchPlayers = getGatherMatch().getPlayers();
		string[] readyPlayers = queue.getPlayers();

		string[] notReady;
		for (uint i = 0; i < matchPlayers.length; i++)
		{
			string username = matchPlayers[i];
			if (readyPlayers.find(username) == -1)
			{
				notReady.push_back(username);
			}
		}
		return notReady;
	}

	bool isReady(string username)
	{
		return queue.isInQueue(username);
	}

	private uint getTotal()
	{
		return getGatherMatch().getPlayerCount();
	}

	bool isEveryoneReady()
	{
		return queue.getCount() >= getTotal();
	}

	void RenderHUD()
	{
		CRules@ rules = getRules();
		GatherMatch@ gatherMatch = getGatherMatch();
		Vec2f pos;

		pos = Vec2f(140, 200);
		string[] notReadyPlayers = getNotReadyPlayers();
		GUI::DrawTextCentered("Not Ready (" + notReadyPlayers.length + ")", pos, color_white);

		for (uint i = 0; i < notReadyPlayers.length; i++)
		{
			string username = notReadyPlayers[i];
			u8 team = gatherMatch.getTeamNum(username);

			int y = 20 + i * 20;
			bool isInServer = getPlayerByUsername(username) !is null;
			SColor color = isInServer ? rules.getTeam(team).color : SColor(255, 100, 100, 100);
			GUI::DrawTextCentered(username, pos + Vec2f(0, y), color);
		}

		pos = Vec2f(getScreenWidth() - 140, 200);
		string[] readyPlayers = getReadyPlayers();
		GUI::DrawTextCentered("Ready (" + readyPlayers.length + ")", pos, color_white);

		for (uint i = 0; i < readyPlayers.length; i++)
		{
			string username = readyPlayers[i];
			u8 team = gatherMatch.getTeamNum(username);

			int y = 20 + i * 20;
			SColor color = rules.getTeam(team).color;
			GUI::DrawTextCentered(username, pos + Vec2f(0, y), color);
		}
	}

	void Clean()
	{
		GatherMatch@ gatherMatch = getGatherMatch();
		string[] players = queue.getPlayers();
		for (uint i = 0; i < players.length; i++)
		{
			string username = players[i];
			if (!gatherMatch.isParticipating(username))
			{
				Remove(username);
			}
		}
	}

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
