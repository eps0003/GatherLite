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
			getNet().server_SendMsg(username + " has vetoed the map (" + queue.getCount() + "/" + getTotal() + ")");

			if (hasEnoughVotes())
			{
				Veto();
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
			getNet().server_SendMsg(username + " has removed their map veto (" + queue.getCount() + "/" + getTotal() + ")");
		}
		else
		{
			getNet().server_SendMsg(username + " has not vetoed the map (" + queue.getCount() + "/" + getTotal() + ")");
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

	private void Veto()
	{
		LoadNextMap();
		getNet().server_SendMsg("The map has been changed");
	}

	void Serialize(CBitStream@ bs)
	{
		queue.Serialize(bs);
	}
}
