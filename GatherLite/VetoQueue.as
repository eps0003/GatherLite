#include "Queue.as"

shared class VetoQueue
{
	private Queue queue;

	VetoQueue(CBitStream@ bs)
	{
		queue = Queue(bs);
	}

	void Add(string username)
	{
		if (queue.Add(username))
		{
			SendMessage(username + " has vetoed the map (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (hasEnoughVotes())
			{
				Veto();
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
		return Maths::Max(1, getGatherMatch().getPlayerCount() * 0.6f);
	}

	private bool hasEnoughVotes()
	{
		return queue.getCount() >= getTotal();
	}

	private void Veto()
	{
		LoadNextMap();
		SendMessage("The map has been changed", ConsoleColour::CRAZY);
	}

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
