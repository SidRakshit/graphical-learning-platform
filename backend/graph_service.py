# backend/graph_service.py
from typing import Optional, List, Dict, Any
from datetime import datetime
import uuid

from db import Neo4jConnection  # Import your Neo4j connection class
import models  # Import your Pydantic models


class GraphDBService:
    def __init__(self, db_connection: Neo4jConnection):
        self.db_conn = db_connection

    async def create_root_interaction_node(
        self,
        user_id: str,
        user_prompt: str,
        summary_title: Optional[str],
        llm_response: str,  # LLM response is passed in
    ) -> models.InteractionNode:
        """
        Creates a new root InteractionNode in the database.
        """
        node_id = str(uuid.uuid4())
        current_timestamp = datetime.utcnow()

        query = """
        CREATE (i:InteractionNode {
            node_id: $node_id,
            user_prompt: $user_prompt,
            llm_response: $llm_response,
            timestamp: $timestamp,
            summary_title: $summary_title,
            is_starting_node: true,
            user_id: $user_id_param
        })
        RETURN i.node_id AS node_id, i.user_prompt AS user_prompt, i.llm_response AS llm_response,
               i.timestamp AS timestamp, i.summary_title AS summary_title,
               i.is_starting_node AS is_starting_node, i.user_id AS user_id
        """
        params = {
            "node_id": node_id,
            "user_prompt": user_prompt,
            "llm_response": llm_response,
            "timestamp": current_timestamp,
            "summary_title": summary_title,
            "user_id_param": user_id,
        }
        try:
            results = self.db_conn.query(query, params)
            if not results or not results[0]:
                # This should ideally not happen if CREATE is successful
                raise Exception(
                    "Failed to create interaction node in database (no results)."
                )  # More specific exception?

            created_node_data = dict(results[0])

            # Ensure timestamp is Python datetime for Pydantic model
            if "timestamp" in created_node_data and not isinstance(
                created_node_data["timestamp"], datetime
            ):
                if hasattr(created_node_data["timestamp"], "to_native"):
                    created_node_data["timestamp"] = created_node_data[
                        "timestamp"
                    ].to_native()
                else:
                    # Log this or handle as an error more strictly
                    print(
                        f"Warning: Root node timestamp type unknown or not auto-converted for node {created_node_data.get('node_id')}"
                    )

            return models.InteractionNode(**created_node_data)
        except Exception as e:
            # Log the exception (e.g., using a proper logger)
            print(
                f"GraphDBService Error: Failed to create root interaction node for user {user_id}: {e}"
            )
            raise  # Re-raise the exception to be handled by the API layer (main.py)

    async def create_branched_interaction_node(
        self,
        parent_node_id: str,
        user_id: str,  # User ID of the person creating the branch
        user_prompt: str,
        summary_title: Optional[str],
        llm_response: str,  # LLM response is passed in
    ) -> models.InteractionNode:
        """
        Creates a new branched InteractionNode and links it to a parent.
        Ensures the parent node belongs to the user.
        """
        # 1. Verify parent node exists and belongs to the current user
        parent_check_query = """
        MATCH (p:InteractionNode {node_id: $parent_node_id, user_id: $user_id})
        RETURN p.node_id AS id
        """
        parent_check_params = {"parent_node_id": parent_node_id, "user_id": user_id}

        parent_results = self.db_conn.query(parent_check_query, parent_check_params)
        if not parent_results or not parent_results[0]:
            # Custom exception for the service layer to indicate "not found or not authorized"
            raise ValueError(
                f"Parent node {parent_node_id} not found or not accessible by user {user_id}."
            )

        # 2. Create the new branched node
        new_node_id = str(uuid.uuid4())
        current_timestamp = datetime.utcnow()

        create_branch_query = """
        CREATE (b:InteractionNode {
            node_id: $node_id,
            user_prompt: $user_prompt,
            llm_response: $llm_response,
            timestamp: $timestamp,
            summary_title: $summary_title,
            is_starting_node: false,
            user_id: $user_id_param
        })
        RETURN b.node_id AS node_id, b.user_prompt AS user_prompt, b.llm_response AS llm_response,
               b.timestamp AS timestamp, b.summary_title AS summary_title,
               b.is_starting_node AS is_starting_node, b.user_id AS user_id
        """
        branch_node_params = {
            "node_id": new_node_id,
            "user_prompt": user_prompt,
            "llm_response": llm_response,
            "timestamp": current_timestamp,
            "summary_title": summary_title,
            "user_id_param": user_id,
        }

        branch_node_results = self.db_conn.query(
            create_branch_query, branch_node_params
        )
        if not branch_node_results or not branch_node_results[0]:
            raise Exception("Failed to create branched interaction node in database.")

        newly_created_node_data = dict(branch_node_results[0])

        # 3. Create the :BRANCHED_TO relationship
        link_query = """
        MATCH (p:InteractionNode {node_id: $parent_node_id})
        MATCH (b:InteractionNode {node_id: $branch_node_id})
        CREATE (p)-[r:BRANCHED_TO {timestamp: $timestamp, created_by: 'user'}]->(b)
        RETURN type(r) AS relationship_type
        """
        link_params = {
            "parent_node_id": parent_node_id,
            "branch_node_id": new_node_id,
            "timestamp": current_timestamp,
        }
        link_results = self.db_conn.query(link_query, link_params)
        if not link_results or not link_results[0].get("relationship_type"):
            # This is more critical. If the node is created but not linked, it's an issue.
            # Consider cleanup logic or a more specific error.
            # For now, we'll let the node be returned but log a strong warning.
            print(
                f"CRITICAL WARNING: Branched node {new_node_id} created but FAILED to link to parent {parent_node_id}."
            )
            # raise Exception(f"Failed to link branch node {new_node_id} to parent {parent_node_id}.")

        if "timestamp" in newly_created_node_data and not isinstance(
            newly_created_node_data["timestamp"], datetime
        ):
            if hasattr(newly_created_node_data["timestamp"], "to_native"):
                newly_created_node_data["timestamp"] = newly_created_node_data[
                    "timestamp"
                ].to_native()
            else:
                print(
                    f"Warning: Branched node timestamp type unknown or not auto-converted for node {newly_created_node_data.get('node_id')}"
                )

        return models.InteractionNode(**newly_created_node_data)

    async def get_interaction_node_by_id(
        self, node_id: str, user_id: str
    ) -> Optional[models.InteractionNode]:
        """
        Retrieves a specific InteractionNode by its ID, ensuring it belongs to the user.
        Returns None if not found or not owned by user.
        """
        query = """
        MATCH (i:InteractionNode {node_id: $node_id, user_id: $user_id_param})
        RETURN
            i.node_id AS node_id, i.user_prompt AS user_prompt, i.llm_response AS llm_response,
            i.timestamp AS timestamp, i.summary_title AS summary_title,
            i.is_starting_node AS is_starting_node, i.user_id AS user_id
        LIMIT 1
        """
        params = {"node_id": node_id, "user_id_param": user_id}

        results = self.db_conn.query(query, params)
        if not results or not results[0]:
            return None

        node_data = dict(results[0])
        if "timestamp" in node_data and not isinstance(
            node_data["timestamp"], datetime
        ):
            if hasattr(node_data["timestamp"], "to_native"):
                node_data["timestamp"] = node_data["timestamp"].to_native()
            else:
                print(
                    f"Warning: Node timestamp type unknown or not auto-converted for node {node_data.get('node_id')}"
                )

        return models.InteractionNode(**node_data)

    async def get_interaction_graph(
        self, start_node_id: str, user_id: str
    ) -> Optional[models.GraphData]:
        """
        Retrieves the full interaction graph (nodes and relationships) starting from
        a given node_id, ensuring all parts belong to the specified user_id.
        Returns None if the start_node_id is not found or not owned by the user.
        """
        # Cypher query to fetch the subgraph
        # 1. Validate start_node and get all distinct nodes in its component for the user
        # 2. Get all relationships BETWEEN those nodes
        query = """
            MATCH (startNode:InteractionNode {node_id: $start_node_id, user_id: $user_id})
            CALL {
                WITH startNode
                MATCH (startNode)-[:BRANCHED_TO*0..]->(n:InteractionNode)
                WHERE n.user_id = startNode.user_id
                RETURN collect(DISTINCT n) AS pathNodes
            }
            WITH startNode, CASE WHEN pathNodes IS NULL THEN [startNode] ELSE pathNodes + [startNode] END AS nodes_in_graph_raw
            UNWIND nodes_in_graph_raw AS n_raw_obj
            WITH collect(DISTINCT n_raw_obj) AS graphNodes

            UNWIND graphNodes AS sourceNode
            UNWIND graphNodes AS targetNode
            OPTIONAL MATCH (sourceNode)-[rel:BRANCHED_TO]->(targetNode)
            WHERE rel IS NOT NULL

            WITH graphNodes, collect(DISTINCT rel) AS graphRelationships
            RETURN
                [node IN graphNodes | {
                    node_id: node.node_id,
                    user_prompt: node.user_prompt,
                    llm_response: node.llm_response,
                    timestamp: node.timestamp,
                    summary_title: node.summary_title,
                    is_starting_node: node.is_starting_node,
                    user_id: node.user_id
                }] AS nodes,
                [r IN graphRelationships | {
                    source: startNode(r).node_id,
                    target: endNode(r).node_id,
                    type: type(r),
                    properties: properties(r)
                }] AS relationships
            """
        params = {"start_node_id": start_node_id, "user_id": user_id}

        try:
            results = self.db_conn.query(query, params)
            if (
                not results or not results[0] or results[0]["nodes"] is None
            ):  # Check if startNode itself was found
                # If the initial MATCH for startNode fails, results will be empty.
                # If it succeeds but there are no paths, nodes list might be just [startNode] and relationships empty.
                # If results[0]["nodes"] is None, it might mean the first MATCH failed.
                # More robust check: verify startNode existence separately or rely on empty nodes list
                # for startNode not found cases for the user.
                # For now, if the main query returns no rows (startNode not found/owned), this check handles it.

                # Check if startNode exists and is owned by user, to differentiate 404 vs empty graph
                start_node_check = await self.get_interaction_node_by_id(
                    start_node_id, user_id
                )
                if not start_node_check:
                    return None  # Start node itself not found or not owned

                # If start node exists, but graph is empty (e.g. isolated node), return it
                return models.GraphData(nodes=[start_node_check], relationships=[])

            raw_graph_data = results[
                0
            ]  # Expecting one row with 'nodes' and 'relationships'

            # Process nodes: convert timestamps
            processed_nodes = []
            for node_dict in raw_graph_data.get("nodes", []):
                if "timestamp" in node_dict and not isinstance(
                    node_dict["timestamp"], datetime
                ):
                    if hasattr(node_dict["timestamp"], "to_native"):
                        node_dict["timestamp"] = node_dict["timestamp"].to_native()
                    # else: log warning or error
                processed_nodes.append(models.InteractionNode(**node_dict))

            # Process relationships: convert timestamp in properties
            processed_relationships = []
            for rel_dict in raw_graph_data.get("relationships", []):
                if "properties" in rel_dict and isinstance(
                    rel_dict["properties"], dict
                ):
                    if "timestamp" in rel_dict["properties"] and not isinstance(
                        rel_dict["properties"]["timestamp"], datetime
                    ):
                        if hasattr(rel_dict["properties"]["timestamp"], "to_native"):
                            rel_dict["properties"]["timestamp"] = rel_dict[
                                "properties"
                            ]["timestamp"].to_native()
                processed_relationships.append(models.RelationshipData(**rel_dict))

            return models.GraphData(
                nodes=processed_nodes, relationships=processed_relationships
            )

        except Exception as e:
            print(
                f"GraphDBService Error: Failed to retrieve graph for start_node {start_node_id}, user {user_id}: {e}"
            )
            raise  # Re-raise to be handled by API layer
