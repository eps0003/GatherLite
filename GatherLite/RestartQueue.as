#include "Queue.as"

shared class RestartQueue
{
	private Queue queue;

	void Add(string username)
	{
		if (queue.Add(username))
		{
			getNet().server_SendMsg(username + " has voted to restart (" + queue.getCount() + "/" + getTotal() + ")");

			if (hasEnoughVotes())
			{
				Restart();
			}
		}
		else
		{
			getNet().server_SendMsg(username + " has already voted to restart (" + queue.getCount() + "/" + getTotal() + ")");
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			getNet().server_SendMsg(username + " has removed their vote to restart (" + queue.getCount() + "/" + getTotal() + ")");
		}
		else
		{
			getNet().server_SendMsg(username + " does not have a vote to restart (" + queue.getCount() + "/" + getTotal() + ")");
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

	private void Restart()
	{
		LoadMap(getMap().getMapName());
		getNet().server_SendMsg("The match has been restarted");
	}
}
