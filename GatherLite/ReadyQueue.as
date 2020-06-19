#include "Queue.as"

shared class ReadyQueue
{
	private Queue queue;

	void Add(string username)
	{
		if (queue.Add(username))
		{
			getNet().server_SendMsg(username + " is now ready (" + queue.getCount() + "/" + getTotal() + ")");

			if (isEveryoneReady())
			{
				getGatherMatch().StartMatch();
			}
		}
		else
		{
			getNet().server_SendMsg(username + " is already ready (" + queue.getCount() + "/" + getTotal() + ")");
		}
	}

	void Remove(string username)
	{
		if (queue.Remove(username))
		{
			getNet().server_SendMsg(username + " is no longer ready (" + queue.getCount() + "/" + getTotal() + ")");
		}
		else
		{
			getNet().server_SendMsg(username + " is already not ready (" + queue.getCount() + "/" + getTotal() + ")");
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
}
