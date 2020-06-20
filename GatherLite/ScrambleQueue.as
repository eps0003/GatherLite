#include "Queue.as"

shared class ScrambleQueue
{
	private Queue queue;

	ScrambleQueue(CBitStream@ bs)
	{
		queue = Queue(bs);
	}

	void Add(string username)
	{
		if (queue.Add(username))
		{
			SendMessage(username + " has voted to scramble teams (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (hasEnoughVotes())
			{
				Scramble();
			}
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You have already voted to scramble teams", ConsoleColour::ERROR, player);
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			SendMessage(username + " has removed their vote to scramble teams (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);
		}
		else
		{
			CPlayer@ player = getPlayerByUsername(username);
			SendMessage("You already do not have a vote to scramble teams", ConsoleColour::ERROR, player);
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

	private uint getTotal()
	{
		return Maths::Max(1, getGatherMatch().getPlayerCount() * 0.6f);
	}

	private bool hasEnoughVotes()
	{
		return queue.getCount() >= getTotal();
	}

	private void Scramble()
	{
		tcpr("<gather> scramble");
		SendMessage("The teams have been scrambled", ConsoleColour::CRAZY);
	}

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
