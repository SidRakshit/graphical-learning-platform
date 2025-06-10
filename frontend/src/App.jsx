import { useState, useCallback, useEffect } from 'react';
import { ReactFlowProvider, ReactFlow } from '@xyflow/react';
import {
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  MarkerType,
  Panel,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import InitialNode from './components/InitialNode.jsx';
import UserNode from './components/UserNode.jsx';
import ResponseNode from './components/ResponseNode.jsx';

const API_BASE_URL = '/api';

const nodeTypes = {
  initial: InitialNode,
  user: UserNode,
  response: ResponseNode,
};

const LoginModal = ({ onLogin }) => {
  const [inputValue, setInputValue] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (inputValue.trim()) {
      const newUser = {
        id: inputValue.trim().toLowerCase().replace(/\s+/g, '-'),
        name: inputValue.trim()
      };
      onLogin(newUser);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-8 rounded-lg shadow-xl max-w-md w-full">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Welcome to Interaction Flow</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="username" className="block text-sm font-medium text-gray-700">
              Enter your name
            </label>
            <input
              type="text"
              id="username"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-gray-900"
              placeholder="Your name"
              required
            />
          </div>
          <button
            type="submit"
            className="w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
          >
            Start
          </button>
        </form>
      </div>
    </div>
  );
};

const Flow = () => {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [user, setUser] = useState(null);
  const [nodeCounter, setNodeCounter] = useState(0);

  const handleLogin = (newUser) => {
      console.log('[handleLogin] New user:', newUser);
    setUser(newUser);
    setNodes([]);
    setEdges([]);
    setNodeCounter(1);
  };

  useEffect(() => {
    console.log('[useEffect] user:', user, 'nodeCounter:', nodeCounter, 'nodes.length:', nodes.length);
    if (user && nodeCounter === 1 && nodes.length === 0) {
      const centerX = window.innerWidth / 2 - 150;
      const centerY = 100;
      console.log('[useEffect] Creating initial node at', centerX, centerY);

      const initialNode = {
        id: 'initial-0',
        type: 'initial',
        position: { x: centerX, y: centerY },
        data: {
          onPrompt: (prompt) => handleInitialPrompt(prompt, centerX, centerY)
        },
      };
      setNodes([initialNode]);
    }
  }, [user, nodeCounter, nodes.length]);

  const handleInitialPrompt = async (prompt, initialX, initialY) => {
    console.log('[handleInitialPrompt] prompt:', prompt, 'user:', user, 'nodeCounter:', nodeCounter);
    if (!user || !user.id) {
      console.error('No user available for initial prompt');
      return;
    }

    const userNodeId = `user-${nodeCounter}`;
    const responseNodeId = `response-${nodeCounter}`;
    console.log('[handleInitialPrompt] Creating userNodeId:', userNodeId, 'responseNodeId:', responseNodeId);

    const baseX = initialX;
    const baseY = initialY + 150;
    
    const userNode = {
      id: userNodeId,
      type: 'user',
      position: { x: baseX, y: baseY },
      data: { prompt: prompt },
    };
    
    const responseNode = {
      id: responseNodeId,
      type: 'response',
      position: { x: baseX, y: baseY + 150 },
      data: {
        isLoading: true,
        onPrompt: (newPrompt) => handleBranch(responseNodeId, newPrompt),
        branchCount: 0
      },
    };
    
    const userEdge = {
      id: `edge-${responseNodeId}-${userNodeId}`,
      source: responseNodeId,
      target: userNodeId,
      sourceHandle: 'source',
      targetHandle: 'target',
      type: 'smoothstep',
      markerEnd: { type: MarkerType.ArrowClosed },
    };
    
    const responseEdge = {
      id: `edge-${userNodeId}-${responseNodeId}`,
      source: userNodeId,
      target: responseNodeId,
      sourceHandle: 'source',
      targetHandle: 'target',
      type: 'smoothstep',
      markerEnd: { type: MarkerType.ArrowClosed },
    };
    
    setNodes(prevNodes => [...prevNodes, userNode, responseNode]);
    setEdges(prevEdges => [...prevEdges, userEdge, responseEdge]);
    setNodeCounter(prev => prev + 1);
    
    try {
      const response = await fetch(`${API_BASE_URL}/interaction-nodes/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': user.id,
        },
        body: JSON.stringify({
          user_prompt: prompt,
          summary_title: null
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      console.log('[handleInitialPrompt] API response:', data);

      setNodes(prevNodes => 
        prevNodes.map(node => 
          node.id === responseNodeId 
            ? { ...node, data: { ...node.data, content: data.llm_response, isLoading: false, nodeId: data.node_id } }
            : node
        )
      );
    } catch (error) {
      console.error('Error getting response:', error);
      setNodes(prevNodes => 
        prevNodes.map(node => 
          node.id === responseNodeId 
            ? { ...node, data: { ...node.data, content: 'Error getting response. Please try again.', isLoading: false } }
            : node
        )
      );
    }
  };

  const handleBranch = useCallback((sourceResponseNodeId, prompt) => {
    console.log('[handleBranch] sourceResponseNodeId:', sourceResponseNodeId, 'prompt:', prompt, 'nodeCounter:', nodeCounter, 'user:', user);
    if (!user) {
      console.error("Cannot branch: User is not logged in.");
      return;
    }

    const newUserNodeId = `user-${nodeCounter}`;
    const newResponseNodeId = `response-${nodeCounter}`;
    console.log('[handleBranch] newUserNodeId:', newUserNodeId, 'newResponseNodeId:', newResponseNodeId);

    // Use setNodes callback to always get the latest nodes state
    setNodes(prevNodes => {
      console.log('[handleBranch] prevNodes array:', prevNodes);
      const sourceNode = prevNodes.find(n => n.id === sourceResponseNodeId);
      console.log('[handleBranch] found sourceNode:', sourceNode);
      const parentApiNodeId = sourceNode?.data?.nodeId;

      if (!parentApiNodeId) {
        console.error("Could not find source node's API ID to create a branch. sourceNode:", sourceNode, "prevNodes:", prevNodes);
        return prevNodes;
      }

      const currentBranchCount = sourceNode.data.branchCount || 0;
      const branchSpacing = 350;
      const verticalOffset = 200;
      const totalWidth = currentBranchCount * branchSpacing;
      const startX = sourceNode.position.x - totalWidth / 2;

      const newUserX = startX + (currentBranchCount * branchSpacing);
      const newUserY = sourceNode.position.y + verticalOffset;

      console.log('[handleBranch] Branch count:', currentBranchCount, 'newUserX:', newUserX, 'newUserY:', newUserY);

      const newUserNode = {
        id: newUserNodeId,
        type: 'user',
        position: { x: newUserX, y: newUserY },
        data: { prompt: prompt },
      };

      const newResponseNode = {
        id: newResponseNodeId,
        type: 'response',
        position: { x: newUserX, y: newUserY + 150 },
        data: {
          isLoading: true,
          onPrompt: (newPrompt) => handleBranch(newResponseNodeId, newPrompt),
          branchCount: 0,
        },
      };

      const updatedSourceNode = {
        ...sourceNode,
        data: {
          ...sourceNode.data,
          branchCount: currentBranchCount + 1,
        },
      };

      // Add edges for the new nodes
      setEdges(prevEdges => {
        console.log('[handleBranch] Adding edges for', newUserNodeId, newResponseNodeId);
        const userEdge = {
          id: `edge-${sourceResponseNodeId}-${newUserNodeId}`,
          source: sourceResponseNodeId,
          target: newUserNodeId,
          sourceHandle: 'source',
          targetHandle: 'target',
          type: 'smoothstep',
          markerEnd: { type: MarkerType.ArrowClosed },
        };
        const responseEdge = {
          id: `edge-${newUserNodeId}-${newResponseNodeId}`,
          source: newUserNodeId,
          target: newResponseNodeId,
          sourceHandle: 'source',
          targetHandle: 'target',
          type: 'smoothstep',
          markerEnd: { type: MarkerType.ArrowClosed },
        };
        return [...prevEdges, userEdge, responseEdge];
      });

      // Update nodeCounter for the next operation
      setNodeCounter(prevCounter => {
        console.log('[handleBranch] Incrementing nodeCounter from', prevCounter, 'to', prevCounter + 1);
        return prevCounter + 1;
      });

      // Async side effect: fetch branch response
      (async () => {
        try {
          const response = await fetch(`${API_BASE_URL}/interaction-nodes/${parentApiNodeId}/branch`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-user-id': user.id,
            },
            body: JSON.stringify({ user_prompt: prompt, summary_title: null }),
          });

          if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
          }

          const data = await response.json();
          console.log('[handleBranch] API branch response:', data);

          setNodes(nodesAfter => 
            nodesAfter.map(node =>
              node.id === newResponseNodeId
                ? { ...node, data: { ...node.data, content: data.llm_response, isLoading: false, nodeId: data.node_id } }
                : node
            )
          );
        } catch (error) {
          console.error('Error creating branch:', error);
          setNodes(nodesAfter =>
            nodesAfter.map(node =>
              node.id === newResponseNodeId
                ? { ...node, data: { ...node.data, content: 'Error creating branch. Please try again.', isLoading: false } }
                : node
            )
          );
        }
      })();

      return prevNodes
        .map(node => (node.id === sourceResponseNodeId ? updatedSourceNode : node))
        .concat(newUserNode, newResponseNode);
    });
  }, [nodeCounter, user]);

  const startNewConversation = () => {
    console.log('[startNewConversation] Resetting conversation for user:', user);
    if (!user) {
      console.error("Cannot start new conversation: no user logged in.");
      return;
    }
    setNodes([]);
    setEdges([]);
    setNodeCounter(1);
  };

  if (!user) {
    return <LoginModal onLogin={handleLogin} />;
  }

  return (
    <div className="h-screen">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={nodeTypes}
        fitView
      >
        <Background />
        <Controls />
        <Panel position="top-right" className="bg-white p-4 rounded-lg shadow-lg">
          <div className="flex items-center gap-4">
            <span className="text-gray-600">Welcome, {user.name}</span>
            <button
              onClick={startNewConversation}
              className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              New Conversation
            </button>
          </div>
        </Panel>
      </ReactFlow>
    </div>
  );
};

const App = () => {
  return (
    <ReactFlowProvider>
      <Flow />
    </ReactFlowProvider>
  );
};

export default App;