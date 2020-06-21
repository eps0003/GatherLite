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
			SendMessage(username + " is now ready (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (isEveryoneReady())
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

	private bool isEveryoneReady()
	{
		return queue.getCount() >= getTotal();
	}

	void RenderHUD()
	{
		CRules@ rules = getRules();
		GatherMatch@ gatherMatch = getGatherMatch();
		Vec2f pos;

		pos = Vec2f(140, 200);
		GUI::DrawTextCentered("Not Ready", pos, color_white);

		string[] notReadyPlayers = getNotReadyPlayers();
		for (uint i = 0; i < notReadyPlayers.length; i++)
		{
			string username = notReadyPlayers[i];
			u8 team = gatherMatch.getTeamNum(username);

			int y = 20 + i * 20;
			SColor color = rules.getTeam(team).color;
			GUI::DrawTextCentered(username, pos + Vec2f(0, y), color);
		}

		pos = Vec2f(getScreenWidth() - 140, 200);
		GUI::DrawTextCentered("Ready", pos, color_white);

		string[] readyPlayers = getReadyPlayers();
		for (uint i = 0; i < readyPlayers.length; i++)
		{
			string username = readyPlayers[i];
			u8 team = gatherMatch.getTeamNum(username);

			int y = 20 + i * 20;
			SColor color = rules.getTeam(team).color;
			GUI::DrawTextCentered(username, pos + Vec2f(0, y), color);
		}
	}

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
