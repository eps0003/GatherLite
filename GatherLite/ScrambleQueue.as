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
			bool enoughVotes = hasEnoughVotes();

			if (!enoughVotes && queue.getCount() == 1)
			{
				SendMessage(username + " wants to scramble teams. Type !scramble if you agree", ConsoleColour::CRAZY);
			}

			SendMessage(username + " has voted to scramble teams (" + queue.getCount() + "/" + getTotal() + ")", ConsoleColour::GAME);

			if (enoughVotes)
			{
				getGatherMatch().ScrambleTeams();
				SendMessage("The teams have been scrambled", ConsoleColour::CRAZY);
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

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
