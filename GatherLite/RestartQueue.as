#include "Queue.as"

shared class RestartQueue
{
	private Queue queue;

	RestartQueue(CBitStream@ bs)
	{
		queue = Queue(bs);
	}

	void Add(string username)
	{
		if (queue.Add(username))
		{
			SendMessage(username + " has voted to restart (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (hasEnoughVotes())
			{
				Restart();
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
		return Maths::Max(1, getGatherMatch().getPlayerCount() * 0.6f);
	}

	private bool hasEnoughVotes()
	{
		return queue.getCount() >= getTotal();
	}

	private void Restart()
	{
		LoadMap(getMap().getMapName());
		SendMessage("The match has been restarted", ConsoleColour::CRAZY);
	}

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
