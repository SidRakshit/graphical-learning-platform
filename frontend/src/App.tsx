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
import InitialNode from './components/InitialNode';
import UserNode from './components/UserNode';
import ResponseNode from './components/ResponseNode';

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
    setUser(newUser);
    setNodes([]);
    setEdges([]);
    setNodeCounter(1);
  };

  useEffect(() => {
    if (user && nodeCounter === 1 && nodes.length === 0) {
      const centerX = window.innerWidth / 2 - 150;
      const centerY = 100;

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
    if (!user || !user.id) {
      console.error('No user available for initial prompt');
      return;
    }

    const userNodeId = `user-${nodeCounter}`;
    const responseNodeId = `response-${nodeCounter}`;
    
    const userNode = {
      id: userNodeId,
      type: 'user',
      position: { x: initialX, y: initialY },
      data: { prompt: prompt },
    };
    
    const responseNode = {
      id: responseNodeId,
      type: 'response',
      position: { x: initialX, y: initialY + 150 },
      data: {
        isLoading: true,
        onPrompt: (newPrompt) => handleBranch(responseNodeId, newPrompt),
        branchCount: 0
      },
    };
    
    // CORRECTED: Create only one edge from user to response
    const responseEdge = {
      id: `edge-${userNodeId}-${responseNodeId}`,
      source: userNodeId,
      target: responseNodeId,
      sourceHandle: 'source',
      targetHandle: 'target',
      type: 'smoothstep',
      markerEnd: { type: MarkerType.ArrowClosed },
      animated: true,
      style: { stroke: '#64748b' }
    };
    
    // CORRECTED: Remove initial node and set a single edge, preventing cycles
    setNodes(prevNodes => prevNodes.filter(node => node.id !== 'initial-0').concat(userNode, responseNode));
    setEdges([responseEdge]);
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

  // CORRECTED: Refactored to use functional updates for state setters to avoid stale state
  const handleBranch = useCallback((sourceResponseNodeId, prompt) => {
    if (!user) {
      console.error("Cannot branch: User is not logged in.");
      return;
    }

    setNodeCounter(currentCounter => {
        const newUserNodeId = `user-${currentCounter}`;
        const newResponseNodeId = `response-${currentCounter}`;

        setNodes(prevNodes => {
            const sourceNode = prevNodes.find(n => n.id === sourceResponseNodeId);
            const parentApiNodeId = sourceNode?.data?.nodeId;

            if (!parentApiNodeId) {
                console.error("Could not find source node's API ID to create a branch.");
                return prevNodes;
            }

            const currentBranchCount = sourceNode.data.branchCount || 0;
            const branchSpacing = 350;
            const verticalOffset = 200;
            const totalWidth = currentBranchCount * branchSpacing;
            const startX = sourceNode.position.x - totalWidth / 2;

            const newUserX = startX + (currentBranchCount * branchSpacing);
            const newUserY = sourceNode.position.y + verticalOffset;

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

            setEdges(prevEdges => {
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
        
        return currentCounter + 1;
    });
  }, [user]); // Removed dependencies that caused stale closures

  const startNewConversation = () => {
    if (!user) {
      console.error("Cannot start new conversation: no user logged in.");
      return;
    }
    setNodes([]);
    setEdges([]);
    setNodeCounter(1);
  };

  const onConnect = useCallback((params) => {
    return true;
  }, []);

  const isValidConnection = useCallback((connection) => {
    return true;
  }, []);

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
        onConnect={onConnect}
        isValidConnection={isValidConnection}
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