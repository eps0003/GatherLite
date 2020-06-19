#include "Queue.as"

shared class ScrambleQueue
{
	private Queue queue;

	void Add(string username)
	{
		if (queue.Add(username))
		{
			getNet().server_SendMsg(username + " has voted to scramble teams");

			if (hasEnoughVotes())
			{
				Scramble();
			}
		}
		else
		{
			getNet().server_SendMsg(username + " has already voted to scramble teams (" + queue.getCount() + "/" + getTotal() + ")");
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			getNet().server_SendMsg(username + " has removed their vote to scramble teams (" + queue.getCount() + "/" + getTotal() + ")");
		}
		else
		{
			getNet().server_SendMsg(username + " does not have a vote to scramble teams (" + queue.getCount() + "/" + getTotal() + ")");
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
		getNet().server_SendMsg("The teams have been scrambled");
	}
}
