#include "Queue.as"

shared class VetoQueue
{
	private Queue queue;
	private float requirement;

	VetoQueue(CBitStream@ bs)
	{
		queue = Queue(bs);
	}

	void Add(string username)
	{
		if (queue.Add(username))
		{
			bool enoughVotes = hasEnoughVotes();
			uint count = queue.getCount();

			if (enoughVotes)
			{
				LoadNextMap();
			}
			else if (queue.getCount() == 1)
			{
				SendMessage(username + " wants a different map. Type !veto if you agree", ConsoleColour::CRAZY);
			}

			SendMessage(username + " has vetoed the map (" + count + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (enoughVotes)
			{
				SendMessage("The map has been changed", ConsoleColour::CRAZY);
			}
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You have already vetoed the map", ConsoleColour::ERROR, player);
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			SendMessage(username + " has removed their map veto (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You already have not vetoed the map", ConsoleColour::ERROR, player);
		}
	}

	void Clear()
	{
		queue.Clear();
	}

	bool hasVoted(string username)
	{
		return queue.isInQueue(username);
	}

	bool hasVotes()
	{
		return queue.getCount() > 0;
	}

	private uint getTotal()
	{
		return Maths::Max(1, getGatherMatch().getPlayerCount() * requirement);
	}

	private bool hasEnoughVotes()
	{
		return queue.getCount() >= getTotal();
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

	void LoadConfig(ConfigFile@ cfg)
	{
		requirement = cfg.read_f32("veto_req", 0.6f);
	}
}
