#include "Queue.as"

shared class RestartQueue
{
	private Queue queue;
	private float requirement;

	RestartQueue(CBitStream@ bs)
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
				getGatherMatch().RestartMap();
			}
			else if (queue.getCount() == 1)
			{
				SendMessage(username + " wants to restart the match. Type !restart if you agree", ConsoleColour::CRAZY);
			}

			SendMessage(username + " has voted to restart (" + count + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (enoughVotes)
			{
				SendMessage("The match has been restarted", ConsoleColour::CRAZY);
			}
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You have already voted to restart", ConsoleColour::ERROR, player);
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			SendMessage(username + " has removed their vote to restart (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You already do not have a vote to restart", ConsoleColour::ERROR, player);
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
		requirement = cfg.read_f32("restart_req", 0.6f);
	}
}
